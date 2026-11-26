# legacy/

早期实验，**未维护**，仅作历史记录：

- `lsposed-module/`：基于 LSPosed 的 hook 方案（v0.1–v0.4）。结论是 Vector 2.2 在本机并未真正注入模块类，
  且改数据库 + 属性声明的方式完全不需要 hook，因此废弃。
- `diagnostics/`：用来验证「Xposed 是否真的注入了模块」的最小探测器（canary）。
