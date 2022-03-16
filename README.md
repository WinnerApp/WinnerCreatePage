# winner_create_page

Winner 创建页面自动生成模版

## 安装 Mint

```shell
brew install mint
```

### 安装 wcp

```shell
mint install WinnerApp/WinnerCreatePage@main -f
```

### 运行创建

```
mint run WinnerApp/WinnerCreatePage@main <文件夹名称>
```

## 快速生成模型

- 第一 复制 JSON 字符串在剪贴板

- 第二 mint run WinnerApp/WinnerCreatePage@main model <模型文件名> [-f]

## 快速创建接口

- 第一 复制 JSON 字符串到剪贴板(如果返回JSON则必须)

- 第二 mint run WinnerApp/WinnerCreatePage@main api <接口文件名> [-f]

