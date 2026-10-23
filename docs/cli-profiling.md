# CLI 建档

导入完成后，使用书的 `bookId` 建档。章节编号从 1 开始，每个批次完成后把演员表和建档范围保存到本地 SQLite；再次运行同一命令会从未完成的章节继续。结果包含本次运行耗时、token 用量、模型名、提示词版本、演员表和发音词典。

```sh
export LLM_BASE_URL='https://your-provider.example/v1'
export LLM_KEY='<your-key>'
export LLM_PROFILE_MODEL='<profiling-model>'
export LLM_DIRECTOR_MODEL='<directing-model>'
export LLM_API='chat-completions'

dart run packages/core/bin/pagestage.dart profile <book-id> --through 2
dart run packages/core/bin/pagestage.dart profile <book-id> --through 5 --batch-size 2
```

`LLM_API` 接受 `chat-completions` 或 `responses`，默认 `chat-completions`。`LLM_MODEL` 可为两个模型槽位提供共同值；`LLM_PROFILE_MODEL` 覆盖建档槽位，`LLM_DIRECTOR_MODEL` 覆盖导演槽位，导演默认沿用建档模型。`LLM_JSON_MODE` 默认 `schema`，使用严格 JSON Schema 输出；兼容服务商可显式设置为 `object`，建档模块仍会校验输出结构和角色关联。

`LLM_REASONING_EFFORT` 或配置字段 `llm.reasoningEffort` 指定建档和导演的思考强度。Responses 请求发送 `reasoning.effort`，Chat Completions 请求发送 `reasoning_effort`；可用值以服务商对应接口为准。省略时使用服务商默认值。[DeepSeek Responses](https://api-docs.deepseek.com/api/create-response/) 默认开启思考；快速试听可使用 `deepseek-flash`、`api: "responses"`、`jsonMode: "schema"`、`reasoningEffort: "none"`。

也可在默认忽略的 `.pagestage/providers.json` 中配置：

```json
{
  "llm": {
    "baseUrl": "https://your-provider.example/v1",
    "key": "<your-key>",
    "api": "responses",
    "profileModel": "<profiling-model>",
    "directorModel": "<directing-model>",
    "jsonMode": "schema"
  }
}
```

```sh
dart run packages/core/bin/pagestage.dart profile <book-id> --through 5 \
  --config .pagestage/providers.json
```

环境变量优先于配置文件。key 只用于请求认证；输出错误使用固定类别提示，连接失败或中断、请求超时分别提示，服务商原始响应及认证头不会进入日志。无效 key、余额不足和限流会结束本次命令，退出码为 69；已完成批次继续保留，处理配置或账户问题后重新运行即可。串联命令时用 `&&`，让建档成功后再运行导演。

每批提示词携带已有角色、别名、身份和临时角色；系统旁白由程序维护。角色标识与已有音色引用保持稳定；重复角色合并保留台词量较多一方的音色，旧标识保存为重定向。身份单独保存所属角色与揭晓章节。年龄段使用 `child`、`teen`、`youngAdult`、`middleAged`、`senior`、`unknown`；性别使用 `male`、`female`、`unknown`。发音词典保存词语和数字声调拼音，例如 `长乐` / `chang2 le4`。

自动化测试以假 LLM 返回预先写好的回复，覆盖批次、中断续跑、延伸、稳定标识、合并、身份、临时角色与失败时的原子保存。HTTP 契约测试的响应按 [OpenAI 结构化输出文档](https://developers.openai.com/api/docs/guides/structured-outputs) 构造，属于文档夹具。两本测试书的真实模型建档质量需在具备 key 后人工验收，对应待验项目记录在 GitHub issue #6。
