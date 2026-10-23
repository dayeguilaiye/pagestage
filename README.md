# pagestage

以听为主的小说阅读器。CLI 原型使用纯 Dart core 包，开发环境为 Dart 3.11 或更新版本。

## 运行 CLI

在仓库根目录执行：

```sh
dart pub get
dart run packages/core/bin/pagestage.dart import test/fixtures/books/aq-zh.txt --title 阿Q正传
dart run packages/core/bin/pagestage.dart import test/fixtures/books/pride-and-prejudice-en.txt --title 'Pride and Prejudice'
dart run packages/core/bin/pagestage.dart books
dart run packages/core/bin/pagestage.dart chapters <book-id>
```

`import` 返回书的 `bookId`、语言和章节列表。后续命令使用这个 ID。使用全局参数 `--data-dir <目录>` 选择本地数据目录，默认是当前目录的 `.pagestage`；书和章节通过 drift 保存到该目录的 SQLite 文件。

TXT 先严格按 UTF-8 解码，再尝试 GB18030。GB18030 解码使用 WHATWG Encoding Standard 的索引，支持 GBK 两字节字符与 GB18030 四字节字符。中文的「章」「回」与英文 Chapter 标题用于划分章节，「卷」用于分组；没有章节标题时每约 5000 个 Unicode 字符分成一章。章节正文保留解码后的换行和空白，后续剧本的原文区间使用 Dart UTF-16 偏移量。

测试素材是《阿Q正传》和《傲慢与偏见》的前五章，来源与整理方式见 [素材说明](test/fixtures/books/README.md)。

## 开发验证

```sh
dart format --output=none --set-exit-if-changed packages/core
dart analyze
dart test packages/core/test
```

core 的公共入口是 `package:pagestage_core/pagestage_core.dart`。CLI 命令使用共享的 `CliContext`，业务功能通过书库等模块的公共接口调用。单元测试在 LLM、TTS 服务商接缝使用假适配器，书库测试通过公共接口验证导入结果。
