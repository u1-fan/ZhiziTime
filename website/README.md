# 智子时间官网

官网地址：<https://zhizi-time.u1.fan/>

这是 macOS 智子时间项目的官网静态页面。它使用人文照片作为底层画面，把 `YYYY-MM-DD HH:MM:SS` 时间码固定在中央，并提供 GitHub Releases 下载入口。

## 本地预览

```sh
python3 -m http.server 4173 --directory dist
```

## 发布

应用平台清单位于 `apps.yaml`；正式入口由 `app.u1.fan` 管理。
