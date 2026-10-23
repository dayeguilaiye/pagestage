# 说话人标准答案

两本测试书前五章各一份，共十份。由代理逐句阅读公版文本起草，再由另一轮代理逐句复核；**未经人工校对**，均设置 `humanReviewed: false`。用户确认原型阶段直接采用这些答案（2026-10-23）。来源是[书籍素材](../books/README.md)经过 `Library.importTxt` 导入的章节正文。格式与使用方法见[CLI 评测说明](../../../docs/cli-evaluation.md)。

| 书 | 文件 | 书 ID |
| --- | --- | --- |
| 《阿Q正传》 | `aq-zh-1.draft.json` 至 `aq-zh-5.draft.json` | `15bad7444de48233ea12c39c` |
| *Pride and Prejudice* | `pride-and-prejudice-en-1.draft.json` 至 `-5.draft.json` | `e29cb883376b4e31947bb861` |

同一本书各章使用同一套语义说话人 ID，一份 `speaker-map.json` 即可覆盖整本书。每个文件只列出本章用到的说话人。

## 判定口径

- 直接引语的区间包含引号；`……说：`、`said Mrs. Bennet` 等说话提示归旁白。
- 《阿Q正传》的叙述者是第一人称立传者“我”，各章统一使用 `narrator`。用“他想”“心里想”明确引出、并以阿Q口吻说出的思想归阿Q；自由间接叙述、转述以及叙述中引用的术语、名言归旁白。
- 无名群众按类别合并，例如 `idle-villagers`；英文中一次性出场的无名说话人单独设 ID，例如 `young-lucas`。
- 没有说话提示的连续对白按轮次和内容判定。有争议的判定写在文件的 `notes` 或区间 `note` 中。

## 编写工具

`packages/core/tool/gold.dart` 根据锚点生成文件，偏移量由程序计算：

```sh
cd packages/core
dart run tool/gold.dart dump ../../test/fixtures/books/aq-zh.txt <输出目录>
dart run tool/gold.dart build ../../test/fixtures/books/aq-zh.txt <anchors.json> <gold.json>
dart run tool/gold.dart render ../../test/fixtures/books/aq-zh.txt <gold.json>
```

`dump` 导出各章正文和哈希。`build` 读取 `{"chapterNumber", "speakers", "notes", "segments"}`，每个 segment 写 `speakerId` 和 `until`：区间在上一边界之后首次出现 `until` 的末尾处结束，最后一段省略 `until`。`render` 校验覆盖与哈希，并按 `[speakerId] 原文` 逐段打印，便于逐句复核。
