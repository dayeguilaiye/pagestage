# 许可证用 AGPL-3.0，外部贡献者签 CLA

pagestage 以 AGPL-3.0 开源：任何人修改后再分发，或者用修改版通过网络对外提供服务，都必须公开源码。我们以后可能做付费的托管服务，宽松的许可证会允许别人把 App 闭源、换个皮直接拿去卖。GPL 系许可证和 App Store 的使用条款至今仍有冲突，VLC 在 2011 年就因为一位贡献者的投诉被下架；但只要作者持有全部版权，就可以自己上架 App Store，以后也能另外提供商业授权。所以外部贡献在合并之前必须签 CLA。Immich、Ente、AppFlowy 和 Kelivo 都是 AGPL 的 Flutter 应用，目前都在 App Store 上架。

## Considered Options

- MPL-2.0：只要求修改过的文件开源，不需要 CLA，和 App Store 兼容；但别人可以把它和闭源代码组合成自己的产品。
- Apache-2.0 或 MIT：最宽松，别人可以直接闭源换皮。

## Consequences

- 接受第一个外部 PR 之前，要先配好 CLA（例如 GitHub 上的 CLA Assistant），并补上 LICENSE 文件。
- CLA 会劝退一部分贡献者。
- 引入依赖时要确认它的许可证能并入 AGPL-3.0；Flutter 生态常见的 BSD、MIT、Apache-2.0 都可以。
