# wx_login

基于文章内容整理的 Flutter 第三方登录 demo，覆盖：

- 微信登录：`fluwx`
- QQ 登录：`tencent_kit`
- 页面内讲解：资质申请、SDK 初始化、授权回调、后端换票据、排坑清单

## Demo 结构

当前首页不是单纯的两个按钮，而是把文章里的核心点拆成了 4 个部分：

1. 文章内容拆解
2. 当前配置展示
3. 微信 / QQ 登录演示
4. 常见坑排查日志

你可以直接在 [`lib/main.dart`](./lib/main.dart) 里看到完整示例代码。

## 依赖

```yaml
fluwx: ^5.7.5
tencent_kit: ^6.2.0
```

`QQ` 这边采用 `tencent_kit` 的脚本化配置方式，避免手工改太多原生文件。

## 运行前先改这 4 组配置

### 1. Dart 启动参数

运行时通过 `--dart-define` 传入真实配置：

```bash
flutter run \
  --dart-define=WX_APP_ID=你的微信AppID \
  --dart-define=WX_UNIVERSAL_LINK=https://你的域名/universal_link/wx_login/wechat/ \
  --dart-define=QQ_APP_ID=你的QQAppID \
  --dart-define=QQ_UNIVERSAL_LINK=https://你的域名/universal_link/wx_login/qq_conn/你的QQAppID/
```

### 2. `pubspec.yaml` 里的 QQ 配置

把下面两项替换成真实值：

```yaml
tencent_kit:
  app_id: "123456789"
  universal_link: "https://your.domain.com/universal_link/wx_login/qq_conn/123456789/"
```

### 3. iOS `Info.plist`

当前已经保留了微信 URL Scheme 占位值：

```xml
<string>wx_replace_with_appid</string>
```

需要替换成真实微信 AppID。

QQ 相关的 URL Scheme 会在执行 `pod install` 后根据 `pubspec.yaml` 里的 `tencent_kit` 配置自动写入。

### 4. iOS `Runner.entitlements`

`pod install` 后项目里会生成 [`ios/Runner/Runner.entitlements`](./ios/Runner/Runner.entitlements)，里面默认是占位域名：

```xml
<string>applinks:your.domain.com</string>
```

这个域名必须替换成你自己的 Universal Link 域名，否则 QQ iOS 回调不会完整。

另外，这个 demo 已经移除了 `UIApplicationSceneManifest`，原因很直接：

- `fluwx` 支持 SceneDelegate / AppDelegate 两种模式
- `tencent_kit` 当前不支持 SceneDelegate
- 为了让微信和 QQ 登录都能走通，这里统一回到 AppDelegate 路线

### 5. Android / iOS 开放平台后台

文章里强调的这几项，必须和工程保持一致：

- 微信：包名、应用签名、Bundle ID、Universal Link
- QQ：包名、签名、Bundle ID、Universal Link

## 安装步骤

### 1. 拉依赖

```bash
flutter pub get
```

### 2. iOS 执行 CocoaPods

```bash
cd ios
pod install
cd ..
```

如果 `tencent_kit` 在你的本机第一次安装 CocoaPods 插件脚本，可能需要先安装 `plist`：

```bash
sudo gem install plist
```

### 3. 真机运行

第三方登录优先用真机测试，模拟器经常会出现：

- 拉不起客户端
- 回调收不到
- Universal Link 行为和真机不一致

## 这个 demo 对应文章里的哪些重点

### 1. 微信只拿 `code`

微信登录成功后，页面会记录最近一次 `code`。这个 `code` 应该交给后端，由后端去微信服务端换 `access_token` 和用户信息。

### 2. QQ 同时演示两种模式

- `QQ 登录`：客户端模式，返回 `openid` 和 `accessToken`
- `QQ Server-Side 登录`：服务端模式，`auth code` 放在 `accessToken` 字段里

### 3. 页面内置排坑提醒

首页已经把文章最后那几类问题做成了排查卡片：

- Android 微信授权页拉不起来
- iOS URL Scheme / Universal Links 配置缺失
- Release 包签名和调试签名不一致
- 第三方登录失败时缺少兜底方案

## 建议排查顺序

一旦登录失败，不要先怀疑 Flutter 代码，先按这个顺序核对：

1. AppID 是否正确
2. 包名 / Bundle ID 是否一致
3. Android 签名 / iOS 证书是否匹配
4. Universal Link 与 `apple-app-site-association` 是否正确
5. 是否在真机上测试

## 测试

首页 widget test 已改成只验证 UI 标题，不依赖真实 SDK 回调，可直接跑：

```bash
flutter test
```
