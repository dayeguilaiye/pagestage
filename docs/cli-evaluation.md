# CLI 说话人准确率评测

`evaluate` 把已保存的剧本与标准答案按原文区间比对，输出说话人准确率、出错台词、所用模型和提示词版本。命令读取本地书、演员表和剧本，运行过程无需服务商 key。

## 使用

先导入素材，完成建档和导演，再查看演员表中的说话人 ID：

```sh
dart run packages/core/bin/pagestage.dart cast list <book-id>
```

人工核对标准答案中的语义说话人与这次演员表的对应关系，写入本地的 `speaker-map.json`。JSON 左侧是标准答案的说话人 ID，右侧是演员表中对应成员的 ID。以下示例假设演员表 ID 为 `narrator`、`character-1` 和 `character-2`：

```json
{
  "narrator": "narrator",
  "mr-bennet": "character-1",
  "mrs-bennet": "character-2"
}
```

然后运行：

```sh
dart run packages/core/bin/pagestage.dart evaluate <book-id> 1 \
  --gold test/fixtures/evaluation/pride-and-prejudice-en-1.draft.json \
  --speaker-map speaker-map.json
```

全局 `--data-dir <目录>` 指定保存书和剧本的目录。CLI 返回 JSON；需要留存结果时，可用 shell 重定向到本地文件。

映射是人工明确填写的对应关系。名称和别名供人工判断，程序使用稳定的演员表 ID；演员表已有的 ID 重定向会被解析。每个在标准答案区间中使用的说话人都需要映射，不同语义说话人的非空目标 ID 必须不同。映射文件可以包含同一本书其他章节所需的额外条目。

如果模型完全遗漏了某个角色，在映射中显式写 `null`，表示演员表里没有对应成员。该角色的全部有效字符计为错误。例如正文为 `AB`，标准答案把 `A` 归旁白、`B` 归主角，而剧本把二者都归旁白；将主角映射为 `null`，结果为 `correctCharacters: 1`、`totalCharacters: 2`、`accuracy: 0.5`。缺少映射键或填入不存在的非空 ID 会作为配置错误报出，便于区分模型漏识别与映射文件笔误。

## 标准答案格式

文件采用 UTF-8 JSON，`schemaVersion` 为 `1`。下面是正文 `AB` 的完整格式示例：

```json
{
  "schemaVersion": 1,
  "offsetUnit": "utf16",
  "bookId": "example-book",
  "chapterNumber": 1,
  "sourceTextHash": "38164fbd17603d73f696b8b4d72664d735bb6a7c88577687fd2ae33fd6964153",
  "humanReviewed": false,
  "speakers": {
    "narrator": "旁白",
    "hero": "主角"
  },
  "spans": [
    {"start": 0, "end": 1, "speakerId": "narrator"},
    {"start": 1, "end": 2, "speakerId": "hero", "note": "待人工确认"}
  ],
  "notes": ["DRAFT — awaiting human correction."]
}
```

`bookId` 对应导入结果，`chapterNumber` 从 1 开始。`sourceTextHash` 是导入后的完整 `Chapter.text` 以 UTF-8 编码计算的 SHA-256，包含正文前后的空白。标题已在导入时独立保存。

`start` 和 `end` 使用 Dart UTF-16 偏移量，表示闭开区间 `[start,end)`；例如 `𠀀` 占两个偏移单位。所有区间必须按顺序连续覆盖整章正文，边界落在 Unicode 标量之间。`speakers` 提供语义 ID 与显示名称，`spans[].speakerId` 引用该名录。`note` 和顶层 `notes` 可记录待复核事项。

`humanReviewed` 明确表示这份标准答案是否已由人完整校对。仓库中的十份标准答案都为 `false`。人工确认角色、对白边界和全文覆盖后，在自行维护的标准答案中将其设为 `true`。

## 计分与输出

计分单位为 **Unicode 标量**，忽略 Unicode `White_Space` 属性中的字符。标点和引号参与计分；`𠀀` 等补充字符计为 1。说话提示、非正文和第三人称叙述也按标准答案中的说话人比对，演播模式不改变这项质量评测。

程序计算每条剧本台词与标准答案区间的交集。某个交集内的说话人正确，其有效字符全部计入正确数。因此，一条台词拆成多条，或多条相邻台词合为一条，都会按实际覆盖的原文得到相同权重。公式为 `accuracy = correctCharacters / totalCharacters`；全章只有空白时准确率为 `null`。

输出含以下信息：

- `bookId`、`chapterNumber`、`sourceTextHash`、`model`、`promptVersion`，以及解析后的 `speakerMap`。
- `correctCharacters`、`totalCharacters`、`accuracy` 和 `weighting`。
- `errors`：出错台词的序号、原文区间和文本；每项的 `mismatches` 列出错误交集、期望语义说话人、期望演员表 ID、实际说话人和错误字符数。
- `status` 与 `humanReviewed`：草稿结果固定显示 `status: "draft"`，并带 `warning` 提醒其尚未人工确认；零分和满分也保留这一标记。

成功完成比对返回退出码 0，准确率高低不改变退出码。参数问题返回 64；书、章节、正文哈希、区间或映射不匹配返回 65。旧正文的剧本和标准答案需要按当前正文重新生成后再评测。

## 公版草稿

[十份标准答案及判定口径](../test/fixtures/evaluation/README.md)覆盖《阿Q正传》和 *Pride and Prejudice* 各前五章。它们由代理起草并逐句复核，未经人工校对，原型阶段经用户确认直接采用；真实模型的测量结果见[原型报告](spike-report.md)。离线测试验证的是比对逻辑。
