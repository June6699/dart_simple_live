# MiSans 字体（子集版）

本目录的字体由小米 MiSans 裁剪而来，仅用于本项目的界面显示。

| 文件 | 字重 | 体积 | 说明 |
|---|---|---|---|
| `MiSans-Regular.ttf` | 400 | 1.60 MB | 正文 |
| `MiSans-Bold.ttf` | 700 | 1.58 MB | 标题 / 强调（`w600` 也会回落到这里） |

## 为什么是子集

MiSans 官方简体中文字重单个约 7.6 MB。两个字重直接用会给安装包加 15 MB 左右，
对电视端没必要。

这里裁到：

- **GB2312 全集**（6763 汉字，覆盖日常中文 99% 以上）
- 项目源码里出现过的**全部字符**（`lib/**/*.dart`、`*.json`、`*.yaml`），保证界面文案零缺字
- ASCII、拉丁补充、通用标点、CJK 标点、全角字符、箭头与几何符号

裁完每个字重约 1.6 MB，两个合计 **3.18 MB**（原版约 16 MB，压到 21%）。

代价：**GB2312 之外的生僻字**（部分人名、地名，如「喆」「珺」「昇」）不在子集里，
会由 Flutter 自动回退到系统字体渲染。这类字只可能出现在主播昵称、房间标题等
动态内容上，不会出现在界面文案里。

## 重新生成

用 [fontTools](https://github.com/fonttools/fonttools) 的 `pyftsubset`：

```bash
python -m fontTools.subset MiSans-Regular.ttf \
  --text-file=charset.txt \
  --output-file=MiSans-Regular.ttf \
  --layout-features=kern,liga,vert,vrt2 \
  --no-hinting --desubroutinize --name-IDs=* --drop-tables+=DSIG
```

`charset.txt` 就是上面说的字符集（GB2312 全集 + 源码字符 + 符号区间），
想更全可以换成 GBK，想更小可以只留 GB2312 一级字（3755 字）。

## 许可

MiSans 由小米发布，免费用于个人与商业用途，可作为嵌入式字体随应用分发，
要求在软件中注明使用了 MiSans 字体（即本文件）。

字体版权归小米科技有限责任公司所有，协议见
<https://hyperos.mi.com/font/faq>。此处仅做字符子集裁剪，未修改字形。
