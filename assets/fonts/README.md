# UI フォント

M PLUS Rounded 1c (SIL Open Font License 1.1)
出典: https://github.com/google/fonts/tree/main/ofl/mplusrounded1c

アプリサイズ削減のため、UI で使用する文字(英数・かな・全角記号・
アプリ内で使う漢字)のみにサブセット化している。サブセット外の文字
(プレイヤー名のレア漢字など)は `fontFamilyFallback` のシステム
フォントで表示される。

## 再生成手順

UI に新しい漢字を追加した場合は再サブセットが必要:

```bash
pip install fonttools brotli
python - <<'EOF'
text = open('lib/main.dart', encoding='utf-8').read()
open('assets/fonts/app_chars.txt', 'w', encoding='utf-8').write(''.join(sorted(set(text))))
EOF
cd assets/fonts
for w in Medium Bold ExtraBold Black; do
  curl -sfL -o "orig_$w.ttf" "https://github.com/google/fonts/raw/main/ofl/mplusrounded1c/MPLUSRounded1c-$w.ttf"
  pyftsubset "orig_$w.ttf" --output-file="MPLUSRounded1c-$w.ttf" \
    --text-file=app_chars.txt \
    --unicodes="U+0020-00FF,U+2010-205F,U+2190-2199,U+3000-30FF,U+31F0-31FF,U+FF00-FFEF" \
    --layout-features='*' --no-hinting
  rm "orig_$w.ttf"
done
```
