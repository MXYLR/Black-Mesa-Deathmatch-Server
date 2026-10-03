# REVERSE_VGUI — BM 客户端 VGUI 面板渲染(源码级实锤,2026-08-24)

对照源码:
- 官方 ValveSoftware/source-sdk-2013(C:/tmp/sdk2013,稀疏检出 src/game)—— BM 客户端的分支基线
- 2018 引擎源码 lua9520/source-engine-2018-hl2_src(C:/tmp/se2018_hl2,稀疏检出 game/)—— 同一格式,佐证稳定性
- SourcePauseTool(C:/tmp/spt_ref)—— SDK/bms_new 头文件 + game_detection 的 BMS 检测

## VGUIMenu usermessage 线上格式(两版源码完全一致)

```
string panelname
byte   show
byte   count
count × ( string key, string value )
```

- 处理器:`clientmode_shared.cpp::__MsgFunc_VGUIMenu`
  (`game/client/clientmode_shared.cpp:199`,2013 版同位置)
- 客户端把 pairs 组装成 KeyValues("data") → `viewport->SetData(keys)` → `ShowPanel(viewport, bShow)`
- panelname 找不到面板 → 静默返回(DevMsg 被注释掉,无崩溃风险)
- **坑(实锤)**:show 之后客户端无条件读 1 个 count 字节。旧实现发的是单一文本串,
  文本首字节被当 count(中文 UTF-8 首字节 0xE4=228)→ 读 228 对空串 → 空页面。
  正确姿势必须发 count + key/value 对。
- 特例:panelname=="info" 且 type==2(URL)→ 白名单协议检查;我们只用 type=0 不走此路。

## "info" 面板 = CHL2MPTextWindow(hl2mp/ui/hl2mptextwindow.cpp,基类 CTextWindow)

- `PANEL_INFO == "info"`(game/shared/viewport_panel_names.h:24)
- hl2mp viewport `CreatePanelByName`:PANEL_INFO → `new CHL2MPTextWindow`
- SetData 键:`type`(int,0=纯文本/1=index/2=URL/3=file)、`title`、`msg`、
  `msg_fallback`(URL 被禁时的纯文本兜底)、`cmd`(int,TEXTWINDOW_CMD_* 枚举)、`unload`(bool)
- type=0 → `ShowText(msg)` → 多行 TextEntry 逐字渲染(msg 里 `\n` 换行有效)
- title 显示在 MessageTitle label(窗口标题栏本身隐藏)
- 全屏 + 背景板(CHL2MPTextWindow::PerformLayout 拉伸全屏),OK 按钮(#PropertyDialog_OK)
  获得焦点,点击关闭面板直到下一次推送
- 面板捕获鼠标(`SetMouseInputEnabled(true)`)——比赛中推全屏页会锁鼠标瞄准,
  但 xms 的投票面板同款行为,且我们的页面只在 MatchWait 倒计时(玩家冻结)和投票期推送
- `IsInfoPanelAllowed()` 基类默认 `{ return true; }`(clientmode_shared.h:133),
  hl2mp 不覆盖、TF 才覆盖 → BM 客户端任何状态都能显示 info 面板
- 渲染路径:vgui TextEntry SetText → 内部转 wchar,**无 vsnprintf**,CP936 悬空尾字节无崩溃风险
  (SafeTail 消毒保留,纯保险)

## "scores" 面板

- 无需载荷:show=1 + count=0,客户端读游戏状态自行渲染
- 客户端特例:hud_takesshots 时截图 + ds_screenshot 事件(不影响功能)

## 插件对应实现(bms_match.sp IN-GAME VGUI PAGE 段)

- `Bms_VGUIPage_Send(iClient, sTitle, sText)`:发 "info" + show=1 + count=3 +
  ("type","0") + ("title",…) + ("msg",…),两端文本过 SafeTail
- `Bms_VGUIPage_Hide/HideAll`:show=0 + count=0
- `Bms_VGUIPage_ShowScoresPanel`:发 "scores" + show=1 + count=0
- 接入点:MatchWait 倒计时页(每秒重推)、投票页(bms_vote_menu_title + sHud2)、
  赛末 scores 面板、!vguitest 测试命令

## 遗留验证

`!vguitest` 实测渲染(格式已实锤正确,剩客户端渲染层面的确认)。
若 BM 客户端对 2013 代码有改动导致不显示,降级方案:HintText HUD + 中心文字。
