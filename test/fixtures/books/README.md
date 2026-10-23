# CLI 原型的公版测试素材

两个 UTF-8 文件各包含完整的前五章。章节正文保留自然段，换行使用 LF；正文区间以导入后的章节文本为准。

| 文件 | 作品 | 来源 |
| --- | --- | --- |
| `aq-zh.txt` | 鲁迅《阿Q正传》，1921–1922 | [维基文库简体文本](https://zh.wikisource.org/zh-hans/阿Q正傳)，底本《鲁迅全集》第一卷（1948），第一章「序」至第五章「生计问题」 |
| `pride-and-prejudice-en.txt` | Jane Austen, *Pride and Prejudice*, 1813 | [Project Gutenberg #1342](https://www.gutenberg.org/ebooks/1342)，[UTF-8 文本](https://www.gutenberg.org/ebooks/1342.txt.utf-8)，Chapter I–V |

取材日期：2026-10-23。作品原文已进入公版；素材仅用于原型开发、离线测试和待人工校对的评测草稿。

中文从第一至第五章的标题和正文段落提取，使用来源页面的简体转换，去除 HTML 排版与零宽页码标记。英文从正文提取，保留标点与自然段，将行宽造成的折行合并为空格，斜体排版符号转换为普通文本，章节标题统一写作 `Chapter I.` 至 `Chapter V.`。来源网站导航、前言、目录、插图及图注、版权页和页眉页脚不属于这两个正文文件。英文原文校对制作人员为 Chuck Greif 与 Online Distributed Proofreading Team；详见来源页面。
