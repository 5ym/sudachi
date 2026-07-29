# sudachi

日本語形態素解析器 [Sudachi](https://github.com/WorksApplications/Sudachi)（Rust 実装の
[sudachi.rs](https://github.com/WorksApplications/sudachi.rs)）と
[SudachiDict](https://github.com/WorksApplications/SudachiDict) を同梱した Docker イメージ。

> 以前は MeCab + mecab-ipadic-NEologd 構成でしたが、NEologd の辞書更新が 2020 年 9 月で
> 止まっているため、辞書が継続的に更新されている Sudachi に置き換えました。

## 使い方

```sh
docker pull ghcr.io/5ym/mecab:latest
```

標準入力から読んで標準出力に書きます。

```sh
$ echo "すもももももももものうち。京都大学に行った。" | docker run --rm -i ghcr.io/5ym/mecab
すもも  名詞,普通名詞,一般,*,*,*        李
も      助詞,係助詞,*,*,*,*             も
もも    名詞,普通名詞,一般,*,*,*        もも
...
京都大学 名詞,固有名詞,一般,*,*,*       京都大学
EOS
```

### 分かち書きだけ欲しいとき

```sh
$ echo "外国人参政権について附属機関で議論した" | docker run --rm -i ghcr.io/5ym/mecab -w
外国人参政権 に つい て 附属 機関 で 議論 し た
```

### 分割単位（A / B / C）

Sudachi は 3 段階の分割粒度を選べます。デフォルトは `C`。

```sh
$ echo "選挙管理委員会" | docker run --rm -i ghcr.io/5ym/mecab -m A -w
選挙 管理 委員 会

$ echo "選挙管理委員会" | docker run --rm -i ghcr.io/5ym/mecab -m C -w
選挙管理委員会
```

### 正規化形・読みも出す

`-a` で全フィールド（正規化形・辞書形・読み・同義語グループ ID）を出力します。

```sh
$ echo "ふとんがふっとんだ" | docker run --rm -i ghcr.io/5ym/mecab -a
ふとん  名詞,普通名詞,一般,*,*,*        布団    ふとん  フトン  0       [13556]
が      助詞,格助詞,*,*,*,*             が      が      ガ      0       []
ふっとん 動詞,一般,*,*,五段-バ行,連用形-撥音便  吹き飛ぶ ふっとぶ フットン 0    []
だ      助動詞,*,*,*,助動詞-タ,終止形-一般      た      だ      ダ      0       []
EOS
```

### ファイルを渡す

```sh
docker run --rm -v "$PWD:/work" -w /work ghcr.io/5ym/mecab input.txt -o output.txt
```

### その他のオプション

```sh
docker run --rm ghcr.io/5ym/mecab --help
```

## タグ

| タグ | 内容 |
| --- | --- |
| `latest` | master の最新ビルド |
| `dict-YYYYMMDD` | 同梱している SudachiDict のバージョン |
| `sha-xxxxxxx` | コミット単位 |

CI は毎月 1 日に走り、新しい SudachiDict が出ていれば取り込んで焼き直します。
対応アーキテクチャは `linux/amd64` と `linux/arm64`。

## カスタマイズ

### 辞書の種類を変える

デフォルトは `core`。`small` / `full` に変えてローカルビルドできます。

```sh
docker build --build-arg DICT_TYPE=full -t sudachi:full .
```

| 種類 | zip サイズ | 内容 |
| --- | --- | --- |
| `small` | 約 40MB | UniDic の語彙のみ |
| `core` | 約 70MB | 基本的な固有名詞を含む（デフォルト） |
| `full` | 約 120MB | 雑多な固有名詞まで全部 |

### ユーザー辞書を足す

[sudachi.json](sudachi.json) を編集して `userDict` にパスを追加し、辞書ごとマウントします。

```sh
docker run --rm -i \
  -v "$PWD/sudachi.json:/opt/sudachi/sudachi.json:ro" \
  -v "$PWD/user.dic:/opt/sudachi/user.dic:ro" \
  ghcr.io/5ym/mecab -w
```

ユーザー辞書のビルドはイメージ内の `sudachi ubuild` で行えます。

```sh
docker run --rm -v "$PWD:/work" -w /work --entrypoint sudachi ghcr.io/5ym/mecab \
  ubuild -s /opt/sudachi/system.dic -o user.dic user_dict.csv
```

## 構成

- ベース: `alpine`
- sudachi.rs を musl 向けにスタティックリンクしてビルド（[Dockerfile](Dockerfile)）
- 辞書と設定は `/opt/sudachi/` に配置
