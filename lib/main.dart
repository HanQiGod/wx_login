import 'package:fluwx/fluwx.dart' as fluwx;
import 'package:flutter/material.dart';

// 传入真实的微信 AppID / Universal Link，避免硬编码。
const String _wxAppId = String.fromEnvironment(
  'WX_APP_ID',
  defaultValue: 'wx_replace_with_appid',
);
const String _wxUniversalLink = String.fromEnvironment(
  'WX_UNIVERSAL_LINK',
  defaultValue: 'https://your.universal.link/path/', // 仅 iOS 需要，可留空。
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '微信登录 Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const WeChatLoginPage(),
    );
  }
}

class WeChatLoginPage extends StatefulWidget {
  const WeChatLoginPage({super.key});

  @override
  State<WeChatLoginPage> createState() => _WeChatLoginPageState();
}

class _WeChatLoginPageState extends State<WeChatLoginPage> {
  final fluwx.Fluwx _fluwx = fluwx.Fluwx();
  fluwx.FluwxCancelable? _authListener;

  String _status = '等待初始化';
  String? _lastCode;

  @override
  void initState() {
    super.initState();
    _bindListener();
    _initWeChat();
  }

  @override
  void dispose() {
    _authListener?.cancel();
    super.dispose();
  }

  void _bindListener() {
    _authListener = _fluwx.addSubscriber((resp) {
      if (resp is fluwx.WeChatAuthResponse) {
        setState(() {
          _lastCode = resp.code;
          _status = resp.errCode == 0
              ? '授权成功，code = ${resp.code}'
              : '授权失败/取消，errCode=${resp.errCode}, errStr=${resp.errStr ?? ''}';
        });
      }
    });
  }

  Future<void> _initWeChat() async {
    setState(() => _status = '注册微信 SDK 中...');
    try {
      final ok = await _fluwx.registerApi(
        appId: _wxAppId,
        doOnIOS: _wxUniversalLink.isNotEmpty,
        universalLink: _wxUniversalLink.isEmpty ? null : _wxUniversalLink,
      );
      setState(() => _status = ok ? 'SDK 注册成功' : 'SDK 注册失败');
    } catch (e) {
      setState(() => _status = '注册异常: $e');
    }
  }

  Future<void> _login() async {
    setState(() => _status = '检查微信客户端...');
    final installed = await _fluwx.isWeChatInstalled;
    if (!installed) {
      setState(() => _status = '未安装微信，请先安装');
      return;
    }

    setState(() => _status = '拉起微信授权中...');
    await _fluwx.authBy(
      which: fluwx.NormalAuth(
        scope: 'snsapi_userinfo',
        state: 'wx_login_demo_state',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('微信登录 Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前状态：$_status'),
            const SizedBox(height: 12),
            if (_lastCode != null) SelectableText('最近一次授权 code：$_lastCode'),
            const Spacer(),
            FilledButton.icon(
              onPressed: _initWeChat,
              icon: const Icon(Icons.link),
              label: const Text('重新注册微信 SDK'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _login,
              icon: const Icon(Icons.login),
              label: const Text('微信登录'),
            ),
            const SizedBox(height: 20),
            const Text(
              '提示：拿到 code 后请发给后端，用 AppSecret 在服务器端换取 access_token 与用户信息。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
