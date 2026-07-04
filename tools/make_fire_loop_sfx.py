"""dragon_fire_flame_loop.wav を dragon_fire_flame_pip.wav から再生成する。

炎SFXはゲーム内の発射間隔(0.14s)で単発音を敷き詰めたループ音源として再生する。
発射ごとに単発音を鳴らし直すと iOS (AVPlayer) の seek→play 再始動レイテンシで
連続音が途切れるため、ループ再生方式に変更した経緯がある。

usage: python3 tools/make_fire_loop_sfx.py
"""

import pathlib
import struct
import wave

AUDIO_DIR = pathlib.Path(__file__).resolve().parent.parent / "assets" / "audio"
SRC = AUDIO_DIR / "dragon_fire_flame_pip.wav"
DST = AUDIO_DIR / "dragon_fire_flame_loop.wav"

PERIOD_SECONDS = 0.14  # lib/main.dart の発射間隔 (_fireTimer = 0.14) と一致させる
REPEATS = 16  # ループ境界(わずかな途切れの可能性)を2.24s間隔まで薄める
FADE_SAMPLES = 88  # 連結点のクリックノイズ防止に末尾約2msをフェードアウト


def main() -> None:
    with wave.open(str(SRC), "rb") as f:
        assert f.getnchannels() == 1 and f.getsampwidth() == 2, "expected 16-bit mono"
        rate = f.getframerate()
        frames = f.readframes(f.getnframes())

    samples = list(struct.unpack(f"<{len(frames) // 2}h", frames))
    n = len(samples)
    for i in range(FADE_SAMPLES):
        idx = n - FADE_SAMPLES + i
        gain = 1.0 - (i + 1) / FADE_SAMPLES
        samples[idx] = int(samples[idx] * gain)

    period = int(round(PERIOD_SECONDS * rate))
    assert period >= n, f"pip ({n} samples) longer than period ({period} samples)"
    loop = (samples + [0] * (period - n)) * REPEATS

    with wave.open(str(DST), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(struct.pack(f"<{len(loop)}h", *loop))

    print(f"wrote {DST}: {len(loop)} samples, {len(loop) / rate:.3f}s @ {rate}Hz")


if __name__ == "__main__":
    main()
