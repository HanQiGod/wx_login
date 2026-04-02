import 'dart:async';

import 'package:fluwx/fluwx.dart' as fluwx;
import 'package:flutter/material.dart';
import 'package:tencent_kit/tencent_kit.dart';

const String _wxAppId = String.fromEnvironment(
  'WX_APP_ID',
  defaultValue: 'wx_replace_with_appid',
);
const String _wxUniversalLink = String.fromEnvironment(
  'WX_UNIVERSAL_LINK',
  defaultValue: 'https://your.domain.com/universal_link/wx_login/wechat/',
);
const String _qqAppId = String.fromEnvironment(
  'QQ_APP_ID',
  defaultValue: '123456789',
);
const String _qqUniversalLink = String.fromEnvironment(
  'QQ_UNIVERSAL_LINK',
  defaultValue:
      'https://your.domain.com/universal_link/wx_login/qq_conn/123456789/',
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.enableSdkBootstrap = true});

  final bool enableSdkBootstrap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F8F6B),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: '微信 / QQ 第三方登录 Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F2),
      ),
      home: SocialLoginDemoPage(autoBootstrap: enableSdkBootstrap),
    );
  }
}

class SocialLoginDemoPage extends StatefulWidget {
  const SocialLoginDemoPage({super.key, this.autoBootstrap = true});

  final bool autoBootstrap;

  @override
  State<SocialLoginDemoPage> createState() => _SocialLoginDemoPageState();
}

class _SocialLoginDemoPageState extends State<SocialLoginDemoPage> {
  final fluwx.Fluwx _fluwx = fluwx.Fluwx();

  fluwx.FluwxCancelable? _wxCancelable;
  StreamSubscription<TencentResp>? _qqSubscription;

  String _wxStatus = '等待配置';
  String _qqStatus = '等待配置';
  String _deviceStatus = '尚未检查客户端环境';
  String? _wechatCode;
  TencentLoginResp? _qqLoginResp;
  final List<_LogEntry> _logs = <_LogEntry>[];

  bool get _hasRealWxConfig =>
      _wxAppId.startsWith('wx') && !_wxAppId.contains('replace');

  bool get _hasRealQqConfig =>
      RegExp(r'^\d+$').hasMatch(_qqAppId) && _qqAppId != '123456789';

  @override
  void initState() {
    super.initState();
    if (widget.autoBootstrap) {
      _bindWechatResponses();
      _bindQqResponses();
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _wxCancelable?.cancel();
    _qqSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _addLog('Demo 已启动，登录链路拆成：资质申请 -> SDK 注册 -> 拉起授权 -> 后端换票据。');
    if (_hasRealWxConfig) {
      await _registerWechat();
    } else {
      setState(() {
        _wxStatus = '请先替换微信 AppID / Universal Link';
      });
      _addLog('微信仍是占位配置，先去微信开放平台申请 AppID。');
    }

    if (_hasRealQqConfig) {
      await _registerQq();
    } else {
      setState(() {
        _qqStatus = '请先替换 QQ AppID / Universal Link';
      });
      _addLog('QQ 仍是占位配置，先去 QQ 互联申请 AppID。');
    }

    await _inspectEnvironment();
  }

  void _bindWechatResponses() {
    _wxCancelable = _fluwx.addSubscriber((fluwx.WeChatResponse resp) {
      if (!mounted || resp is! fluwx.WeChatAuthResponse) {
        return;
      }
      if (resp.errCode == 0 && (resp.code?.isNotEmpty ?? false)) {
        setState(() {
          _wechatCode = resp.code;
          _wxStatus = '微信授权成功，拿到 code，下一步交给后端换 token。';
        });
        _addLog('微信回调成功，code=${resp.code}');
      } else {
        setState(() {
          _wxStatus = '微信授权失败/取消，errCode=${resp.errCode}';
        });
        _addLog('微信回调失败，errCode=${resp.errCode} errStr=${resp.errStr ?? ''}');
      }
    });
  }

  void _bindQqResponses() {
    _qqSubscription = TencentKitPlatform.instance.respStream().listen(
      _handleTencentResponse,
    );
  }

  void _handleTencentResponse(TencentResp resp) {
    if (!mounted) {
      return;
    }
    if (resp is TencentLoginResp) {
      _qqLoginResp = resp;
      final bool success = resp.isSuccessful;
      final String tokenValue = resp.accessToken ?? '';
      final int tokenPrefixLength = tokenValue.length > 10
          ? 10
          : tokenValue.length;
      final String tokenLabel = tokenValue.isEmpty
          ? '空'
          : '${tokenValue.substring(0, tokenPrefixLength)}...';
      setState(() {
        _qqStatus = success
            ? 'QQ 授权成功，openid=${resp.openid ?? '-'}'
            : 'QQ 授权失败，ret=${resp.ret} msg=${resp.msg ?? ''}';
      });
      _addLog(
        success
            ? 'QQ 回调成功，openid=${resp.openid ?? '-'} accessToken/code=$tokenLabel'
            : 'QQ 回调失败，ret=${resp.ret} msg=${resp.msg ?? ''}',
      );
      return;
    }

    if (resp is TencentShareMsgResp) {
      _addLog('QQ 分享回调，ret=${resp.ret} msg=${resp.msg ?? ''}');
      return;
    }

    _addLog('收到未单独处理的 QQ 回调：${resp.runtimeType}');
  }

  Future<void> _inspectEnvironment() async {
    try {
      final bool wxInstalled = await _fluwx.isWeChatInstalled;
      final bool qqInstalled = await TencentKitPlatform.instance
          .isQQInstalled();
      final bool timInstalled = await TencentKitPlatform.instance
          .isTIMInstalled();
      if (!mounted) {
        return;
      }
      setState(() {
        _deviceStatus =
            '微信: ${wxInstalled ? '已安装' : '未安装'}  |  QQ: ${qqInstalled ? '已安装' : '未安装'}  |  TIM: ${timInstalled ? '已安装' : '未安装'}';
      });
      _addLog('环境检查完成，微信=$wxInstalled QQ=$qqInstalled TIM=$timInstalled');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _deviceStatus = '环境检查失败：$error';
      });
      _addLog('环境检查异常：$error');
    }
  }

  Future<bool> _registerWechat() async {
    if (!_hasRealWxConfig) {
      setState(() {
        _wxStatus = '微信配置还是占位值，先替换 AppID 和 Universal Link';
      });
      return false;
    }

    setState(() {
      _wxStatus = '正在注册微信 SDK...';
    });
    try {
      final bool result = await _fluwx.registerApi(
        appId: _wxAppId,
        doOnIOS: _wxUniversalLink.isNotEmpty,
        universalLink: _wxUniversalLink,
      );
      if (!mounted) {
        return result;
      }
      setState(() {
        _wxStatus = result ? '微信 SDK 注册成功' : '微信 SDK 注册失败';
      });
      _addLog('微信 SDK 注册结果：$result');
      return result;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _wxStatus = '微信 SDK 注册异常：$error';
      });
      _addLog('微信 SDK 注册异常：$error');
      return false;
    }
  }

  Future<bool> _registerQq() async {
    if (!_hasRealQqConfig) {
      setState(() {
        _qqStatus = 'QQ 配置还是占位值，先替换 AppID 和 Universal Link';
      });
      return false;
    }

    setState(() {
      _qqStatus = '正在授权隐私并注册 QQ SDK...';
    });
    try {
      await TencentKitPlatform.instance.setIsPermissionGranted(granted: true);
      await TencentKitPlatform.instance.registerApp(
        appId: _qqAppId,
        universalLink: _qqUniversalLink,
      );
      setState(() {
        _qqStatus = 'QQ SDK 注册成功';
      });
      _addLog('QQ SDK 注册调用完成。');
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _qqStatus = 'QQ SDK 注册异常：$error';
      });
      _addLog('QQ SDK 注册异常：$error');
      return false;
    }
  }

  Future<void> _wechatLogin() async {
    if (!await _registerWechat()) {
      return;
    }

    final bool installed = await _fluwx.isWeChatInstalled;
    if (!mounted) {
      return;
    }
    if (!installed) {
      setState(() {
        _wxStatus = '未安装微信，建议切到手机号验证码或游客模式兜底';
      });
      _addLog('微信客户端不存在，未发起授权。');
      return;
    }

    setState(() {
      _wxStatus = '正在拉起微信授权页...';
    });
    final bool accepted = await _fluwx.authBy(
      which: fluwx.NormalAuth(
        scope: 'snsapi_userinfo',
        state: 'wx_login_demo_state',
      ),
    );
    if (!mounted) {
      return;
    }
    if (!accepted) {
      setState(() {
        _wxStatus = '微信授权请求未成功发出，请检查签名 / 包名 / Universal Link';
      });
      _addLog('微信授权请求未成功发出。');
    } else {
      _addLog('微信授权页已拉起，等待回调。');
    }
  }

  Future<void> _qqLogin() async {
    if (!await _registerQq()) {
      return;
    }

    final bool installed = await TencentKitPlatform.instance.isQQInstalled();
    if (!mounted) {
      return;
    }
    if (!installed) {
      setState(() {
        _qqStatus = '未安装 QQ，建议使用网页登录或手机号兜底';
      });
      _addLog('QQ 客户端不存在，未发起客户端授权。');
      return;
    }

    setState(() {
      _qqStatus = '正在拉起 QQ 客户端授权页...';
    });
    await TencentKitPlatform.instance.login(
      scope: <String>[TencentScope.kGetSimpleUserInfo],
    );
    _addLog('QQ 客户端授权请求已发出，等待回调。');
  }

  Future<void> _qqServerSideLogin() async {
    if (!await _registerQq()) {
      return;
    }

    setState(() {
      _qqStatus = '正在发起 QQ Server-Side 授权...';
    });
    await TencentKitPlatform.instance.loginServerSide(
      scope: <String>[TencentScope.kGetUserInfo],
    );
    _addLog('QQ Server-Side 授权请求已发出，成功后 accessToken 字段里会放 auth code。');
  }

  void _addLog(String message) {
    final DateTime now = DateTime.now();
    final String time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _logs.insert(0, _LogEntry(time: time, message: message));
      if (_logs.length > 12) {
        _logs.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('微信 / QQ 第三方登录 Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _HeroPanel(
            title: '从资质申请到授权回调，一屏把核心点讲清楚',
            subtitle:
                '这不是只放两个按钮的空壳 demo，而是把文章里的完整链路拆成可操作页面：先核对资质，再注册 SDK，最后发起授权并把结果交给后端。',
            tags: const <String>[
              '资质先行',
              '签名匹配',
              'Universal Links',
              '后端换票据',
              '兜底登录',
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '文章内容拆解',
            description: '这四步是第三方登录的主链路，前两步配错，后面代码写得再对也调不通。',
            child: Column(
              children: _guideSteps
                  .map(
                    (_GuideStep step) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StepTile(step: step),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '当前示例配置',
            description:
                '下面这些值默认都是占位。跑真机前，先把 AppID、包名签名、Bundle ID、Universal Link 和开放平台后台保持一致。',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF12231B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: SelectableText(
                [
                  'WX_APP_ID=$_wxAppId',
                  'WX_UNIVERSAL_LINK=$_wxUniversalLink',
                  'QQ_APP_ID=$_qqAppId',
                  'QQ_UNIVERSAL_LINK=$_qqUniversalLink',
                ].join('\n'),
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFE2F3E9),
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '登录演示',
            description:
                '微信返回 code；QQ 客户端模式返回 accessToken/openid；QQ Server-Side 模式把 auth code 放在 accessToken 字段里。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatusPane(
                      title: '微信状态',
                      value: _wxStatus,
                      footnote: _wechatCode == null
                          ? '成功后会在日志里记录 code，再由后端换业务 token。'
                          : '最近一次 code：$_wechatCode',
                      accentColor: const Color(0xFF1AAD19),
                    ),
                    _StatusPane(
                      title: 'QQ 状态',
                      value: _qqStatus,
                      footnote: _qqLoginResp == null
                          ? '客户端模式更接近文章写法，Server-Side 更方便后端接管授权。'
                          : '最近一次 openid：${_qqLoginResp?.openid ?? '-'}',
                      accentColor: const Color(0xFF1284FF),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD6DDD5)),
                  ),
                  child: Text(
                    '客户端环境：$_deviceStatus',
                    style: textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _registerWechat,
                      icon: const Icon(Icons.link),
                      label: const Text('注册微信 SDK'),
                    ),
                    FilledButton.icon(
                      onPressed: _wechatLogin,
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('微信登录'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _registerQq,
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('注册 QQ SDK'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _qqLogin,
                      icon: const Icon(Icons.account_circle_outlined),
                      label: const Text('QQ 登录'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _qqServerSideLogin,
                      icon: const Icon(Icons.cloud_sync_outlined),
                      label: const Text('QQ Server-Side 登录'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _inspectEnvironment,
                      icon: const Icon(Icons.phone_android_outlined),
                      label: const Text('环境检查'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '安全提醒：文章里强调的点是对的，前端只负责拿授权结果，真正的用户体系 token 请统一交给后端生成并回传。',
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4B5A52),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '排坑清单',
            description: '这部分直接对应文章最后那几个高频坑，排查时先看配置，再看真机与证书。',
            child: Column(
              children: _pitfallCards
                  .map(
                    (_PitfallCardData data) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PitfallCard(data: data),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '回调日志',
            description: '授权页是否拉起、回调有没有回来、code/token 长什么样，都能从这里第一时间判断。',
            child: _logs.isEmpty
                ? const Text('还没有日志，点击上面的按钮开始演示。')
                : Column(
                    children: _logs
                        .map(
                          (_LogEntry entry) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFDCE4DB),
                              ),
                            ),
                            child: Text(
                              '[${entry.time}] ${entry.message}',
                              style: textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.title,
    required this.subtitle,
    required this.tags,
  });

  final String title;
  final String subtitle;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0E5E51), Color(0xFF142A3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Flutter 第三方登录示例',
              style: textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFD8EFE5),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (String tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      tag,
                      style: textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E6DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF56655D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});

  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: step.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              step.index,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: step.accentColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  step.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.body,
                  style: textTheme.bodyMedium?.copyWith(height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPane extends StatelessWidget {
  const _StatusPane({
    required this.title,
    required this.value,
    required this.footnote,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String footnote;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: textTheme.bodyLarge?.copyWith(height: 1.45)),
          const SizedBox(height: 10),
          Text(
            footnote,
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF5E6C64),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PitfallCard extends StatelessWidget {
  const _PitfallCard({required this.data});

  final _PitfallCardData data;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            data.title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            data.summary,
            style: textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 10),
          ...data.points.map(
            (String point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(Icons.circle, size: 8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep({
    required this.index,
    required this.title,
    required this.body,
    required this.backgroundColor,
    required this.accentColor,
  });

  final String index;
  final String title;
  final String body;
  final Color backgroundColor;
  final Color accentColor;
}

class _PitfallCardData {
  const _PitfallCardData({
    required this.title,
    required this.summary,
    required this.points,
    required this.backgroundColor,
  });

  final String title;
  final String summary;
  final List<String> points;
  final Color backgroundColor;
}

class _LogEntry {
  const _LogEntry({required this.time, required this.message});

  final String time;
  final String message;
}

const List<_GuideStep> _guideSteps = <_GuideStep>[
  _GuideStep(
    index: '1',
    title: '先拿到开放平台资质',
    body:
        '微信去开放平台，QQ 去 QQ 互联。AppID、包名、签名、Bundle ID 最好在项目初期就固定，不然后面回调地址和签名很容易全部重做。',
    backgroundColor: Color(0xFFE8F6EF),
    accentColor: Color(0xFF1AAD19),
  ),
  _GuideStep(
    index: '2',
    title: '选插件时先看维护状态',
    body:
        '微信这里用 fluwx，QQ 这里用 tencent_kit。一个优先完整能力，一个优先把 QQ SDK 包装成 Flutter API，组合起来比较适合移动端项目。',
    backgroundColor: Color(0xFFF2F6EA),
    accentColor: Color(0xFF6A8B1F),
  ),
  _GuideStep(
    index: '3',
    title: '前端只负责拿授权结果',
    body:
        '微信重点是拿 code，QQ 重点是拿 openid 和 accessToken 或服务端 code。真正的用户体系 token、union 绑定、账号合并都应该由后端完成。',
    backgroundColor: Color(0xFFEAF3FB),
    accentColor: Color(0xFF2267B5),
  ),
  _GuideStep(
    index: '4',
    title: '把兜底方案当成必选项',
    body: '第三方登录不是永远可靠，机型兼容性、网络和平台审核都会干扰。手机号验证码、游客模式或邮箱登录至少要保留一个。',
    backgroundColor: Color(0xFFFBEEDC),
    accentColor: Color(0xFFB86A10),
  ),
];

const List<_PitfallCardData> _pitfallCards = <_PitfallCardData>[
  _PitfallCardData(
    title: 'Android 调不起微信授权页',
    summary: '先查签名，再查包名。绝大多数所谓“没反应”，最后都是开放平台后台填错了签名。',
    points: <String>[
      '微信开放平台要的是应用签名，不是 keystore 的普通 MD5 展示值。',
      'Debug 和 Release 签名不同，开放平台里也要分别核对。',
      '如果个别厂商 ROM 兼容性差，直接准备网页登录或手机号兜底。',
    ],
    backgroundColor: Color(0xFFFFF4E9),
  ),
  _PitfallCardData(
    title: 'iOS 微信 / QQ 回调收不到',
    summary:
        '文章里提到的 URL Scheme 和 Universal Links 不能漏。QQ 这里还要额外注意 tencent_kit 当前不支持 SceneDelegate。',
    points: <String>[
      '微信要核对 URL Scheme、Universal Link 和开放平台后台配置是否完全一致。',
      'QQ 的 Universal Link 需要配好 apple-app-site-association，并保证服务器走 HTTPS。',
      '这个 demo 已把 iOS 场景改回 AppDelegate 路线，避免 SceneDelegate 导致 QQ 无回调。',
    ],
    backgroundColor: Color(0xFFEFF5FF),
  ),
  _PitfallCardData(
    title: '真机能跑，打包后失效',
    summary: 'Debug 通，Release 不通，通常不是 SDK 有鬼，而是签名和证书换了。',
    points: <String>[
      'Android Release 包使用的是正式签名，开放平台后台也要录入正式签名。',
      'iOS Release 包要检查 Distribution 证书、Bundle ID、Associated Domains 是否还是对应正式环境。',
      '排查顺序建议固定：AppID -> 包名 / Bundle ID -> 签名 / 证书 -> Universal Link -> 真机回调。',
    ],
    backgroundColor: Color(0xFFEFF8F4),
  ),
];
