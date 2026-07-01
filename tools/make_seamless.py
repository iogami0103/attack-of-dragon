"""背景画像を横方向にシームレスタイル化する補助スクリプト。

手法 (gradient-domain seam removal):
  1) 画像を w/2 だけ横シフト → 元の継ぎ目が画像中央に来る。
       新しい両端 (col 0 と col w-1) は元画像の隣接ピクセルなので連続。
  2) 中央の継ぎ目の段差 delta = shifted[:, center-1] - shifted[:, center] を計算。
  3) 継ぎ目左右に fade 幅の smoothstep 重みで delta/2 を加減算し、
       両側を同値へ収束させる。テクスチャは保持され色階調だけ滑らかにつながる。

使い方:
  python tools/make_seamless.py assets/backgrounds/lava.png [fade_ratio]
  (上書き保存。fade_ratio は画像幅に対する片側 fade の比率。既定 0.18)
"""

from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from PIL import Image


def smoothstep(t: np.ndarray) -> np.ndarray:
    return t * t * (3.0 - 2.0 * t)


def _vertical_smooth(arr2d: np.ndarray, radius: int) -> np.ndarray:
    """軸 0 方向の box フィルタ (numpy のみ)。arr2d shape (h, c)、出力 shape (h, c)。"""
    if radius <= 0:
        return arr2d
    k = 2 * radius + 1
    padded = np.pad(arr2d, ((radius, radius), (0, 0)), mode="edge")  # h + 2r
    csum = np.cumsum(padded, axis=0)                                 # h + 2r
    # 先頭に 0 行を入れて prefix sum 形式に → out[i] = csum2[i+k] - csum2[i]
    csum = np.concatenate([np.zeros((1, arr2d.shape[1]), dtype=arr2d.dtype), csum], axis=0)  # h + 2r + 1
    out = (csum[k:] - csum[:-k]) / float(k)                          # 長さ h
    return out


def _horizontal_box_blur(strip: np.ndarray, radius: int) -> np.ndarray:
    """軸 1 方向 box blur (numpy のみ)。strip shape (h, w, c)、出力 (h, w, c)。"""
    if radius <= 0:
        return strip
    k = 2 * radius + 1
    padded = np.pad(strip, ((0, 0), (radius, radius), (0, 0)), mode="edge")
    csum = np.cumsum(padded, axis=1)
    csum = np.concatenate([np.zeros((strip.shape[0], 1, strip.shape[2]), dtype=strip.dtype), csum], axis=1)
    return (csum[:, k:] - csum[:, :-k]) / float(k)


def make_seamless(arr: np.ndarray, fade_ratio: float = 0.006,
                  delta_sample_px: int = 4, delta_smooth_ratio: float = 0.04,
                  blur_ratio: float = 0.0015, blur_strip_ratio: float = 0.0025) -> np.ndarray:
    """
    fade_ratio       : 色階調補正の片側 fade 幅 / 画像幅 (既定 0.6%)
    blur_ratio       : 中央継ぎ目への水平ぼかし片側半径 / 画像幅 (既定 0.15%、0 で無効)
    blur_strip_ratio : ぼかしマスクが効く片側帯幅 / 画像幅 (既定 0.25%)
    """
    h, w, c = arr.shape
    arr = arr.astype(np.float32)

    # 1) 半シフトで継ぎ目を中央へ
    shifted = np.roll(arr, w // 2, axis=1)

    fade = max(8, int(w * fade_ratio))
    center = w // 2

    # 2) 継ぎ目段差を計算。1 列だけだと行ノイズがそのまま帯として残るので、
    #    両側 delta_sample_px 列の平均で安定化し、さらに縦方向に平滑化する。
    s = max(1, delta_sample_px)
    left_avg = shifted[:, center - s : center].mean(axis=1)   # (h, c)
    right_avg = shifted[:, center : center + s].mean(axis=1)  # (h, c)
    delta_2d = left_avg - right_avg                            # (h, c)

    # 縦方向の box smoothing (画像高さに比例。既定 4% → 約 30px @724h)
    smooth_radius = max(1, int(h * delta_smooth_ratio))
    delta_2d = _vertical_smooth(delta_2d, smooth_radius)
    delta = delta_2d[:, None, :]                               # (h, 1, c)

    # 3) 重み配列を構築
    weights = np.zeros(w, dtype=np.float32)
    left_t = smoothstep(np.linspace(0.0, 1.0, fade, dtype=np.float32))   # 0→1
    right_t = smoothstep(np.linspace(1.0, 0.0, fade, dtype=np.float32))  # 1→0
    # 左半 [center-fade, center-1] : -delta/2 の方向へ
    weights[center - fade : center] = -0.5 * left_t
    # 右半 [center, center+fade-1] : +delta/2 の方向へ
    weights[center : center + fade] = +0.5 * right_t
    # 結果: out[:, center-1] と out[:, center] が共に (left_edge + right_edge) / 2 になり連続

    correction = delta * weights[None, :, None]
    out = shifted + correction

    # 4) 中央継ぎ目に水平 box blur を「マスク付き」で適用。
    #    色階調補正ではコンテンツ (雲・山の輪郭) の不連続が残るので、
    #    輪郭そのものを溶かして繋がりを自然にする。
    blur_radius = max(0, int(w * blur_ratio))
    if blur_radius > 0:
        # 継ぎ目に隣接する狭い帯のみブレンド (blur_strip_ratio で制御)
        blur_strip_half = max(blur_radius + 2, int(w * blur_strip_ratio))
        x0 = max(0, center - blur_strip_half)
        x1 = min(w, center + blur_strip_half)
        strip = out[:, x0:x1]
        blurred = _horizontal_box_blur(strip, blur_radius)
        # 中央 1.0、端 0 のベル型マスク (smoothstep)
        local_w = x1 - x0
        rel = np.linspace(-1.0, 1.0, local_w, dtype=np.float32)
        bell = 1.0 - np.abs(rel)
        bell = smoothstep(np.clip(bell, 0.0, 1.0))
        bell = bell[None, :, None]
        out[:, x0:x1] = strip * (1.0 - bell) + blurred * bell

    # 5) 端ピクセル一致を念のため保証 (浮動小数点誤差対策)
    out[:, -1] = out[:, 0]

    return np.clip(out, 0.0, 255.0).astype(np.uint8)


def crop_white_bottom(arr: np.ndarray, threshold: int = 248, min_run: int = 5) -> np.ndarray:
    """画像下端の「ほぼ白」(全チャンネル >= threshold) な行を検出してカットし、
    その分だけ垂直方向に引き伸ばして元の高さを維持する。"""
    h = arr.shape[0]
    is_white = (arr >= threshold).all(axis=2).all(axis=1)  # shape (h,) True if entire row is near-white
    # 下から走査して連続して白の行数 n を求める
    n = 0
    for y in range(h - 1, -1, -1):
        if is_white[y]:
            n += 1
        else:
            break
    if n < min_run:
        return arr
    print(f"  cropping {n} white rows from bottom, then stretching to {h}px")
    cropped = arr[: h - n]
    # PIL で良質リサイズ
    pil = Image.fromarray(cropped).resize((arr.shape[1], h), Image.Resampling.LANCZOS)
    return np.array(pil)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: make_seamless.py <image.png> [fade_ratio] [--crop-white-bottom]",
              file=sys.stderr)
        return 2
    path = Path(argv[1])
    fade_ratio = float(argv[2]) if len(argv) >= 3 and not argv[2].startswith("--") else 0.18
    do_crop = "--crop-white-bottom" in argv
    img = Image.open(path).convert("RGB")
    arr = np.array(img)
    print(f"input: {path} {arr.shape}, fade_ratio={fade_ratio}, crop_white={do_crop}")
    if do_crop:
        arr = crop_white_bottom(arr)
    out = make_seamless(arr, fade_ratio=fade_ratio)
    Image.fromarray(out).save(path)
    print(f"saved: {path} ({out.shape})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
