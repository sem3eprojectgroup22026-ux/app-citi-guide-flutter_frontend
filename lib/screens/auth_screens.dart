import 'package:flutter/material.dart';
import '../store.dart';
import '../widgets.dart';

class _AuthScaffold extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  final bool showBack;
  const _AuthScaffold({required this.title, required this.subtitle, required this.children, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (!showBack)
                  Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: const Text('📍', style: TextStyle(fontSize: 22))),
                    const SizedBox(width: 10),
                    Text('CityGuide', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'serif')),
                  ]),
                const SizedBox(height: 24),
                Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold))),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: Theme.of(context).hintColor)),
                const SizedBox(height: 20),
                ...children,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? error;
  final bool meter;
  final TextInputAction action;
  final void Function(String)? onSubmitted;
  const PasswordField({super.key, required this.controller, required this.label, this.error, this.meter = false, this.action = TextInputAction.next, this.onSubmitted});
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool hide = true;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: widget.controller,
        obscureText: hide,
        textInputAction: widget.action,
        onSubmitted: widget.onSubmitted,
        autofillHints: const [AutofillHints.password],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: widget.error,
          suffixIcon: IconButton(tooltip: hide ? 'Show password' : 'Hide password', icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide)),
        ),
      ),
      if (widget.meter) _Meter(widget.controller.text),
    ]);
  }
}

class _Meter extends StatelessWidget {
  final String pw;
  const _Meter(this.pw);
  @override
  Widget build(BuildContext context) {
    final s = pw.isEmpty ? 0 : passwordScore(pw);
    final colors = [Colors.grey, Colors.red, Colors.orange, Colors.lightGreen, Colors.green];
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(child: Container(height: 5, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: i < s ? colors[s] : Colors.grey.shade300, borderRadius: BorderRadius.circular(3)))),
        SizedBox(width: 62, child: Text(pw.isEmpty ? '' : ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'][s], textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}

// Login
class LoginScreen extends StatefulWidget {
  final AppState state;
  const LoginScreen({super.key, required this.state});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), pw = TextEditingController();
  String? error;

  Future<void> submit() async { final r=await widget.state.login(email.text,pw.text); if(!mounted)return; if(!r.ok)setState(()=>error=r.error); }

  @override
  void dispose() {
    email.dispose();
    pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(title: 'Welcome back', subtitle: 'Log in to explore your cities.', children: [
      TextField(controller: email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email')),
      const SizedBox(height: 14),
      PasswordField(controller: pw, label: 'Password', action: TextInputAction.done, onSubmitted: (_) => submit()),
      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ForgotScreen(state: widget.state))), child: const Text('Forgot password?'))),
      if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))),
      FilledButton(onPressed: submit, child: const Text('Log in')),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('New here?'),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(state: widget.state))), child: const Text('Create an account')),
      ]),
      const SizedBox(height: 8),
      
    ]);
  }
}

// Register
class RegisterScreen extends StatefulWidget {
  final AppState state;
  const RegisterScreen({super.key, required this.state});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController(), email = TextEditingController(), pw = TextEditingController(), cf = TextEditingController();
  Map<String, String> errs = {};
  String? error;

  Future<void> submit() async { final r=await widget.state.register(name.text,email.text,pw.text,cf.text); if(!mounted)return; if(!r.ok){setState(()=>errs=r.errors); if(errs.isEmpty)setState(()=>error=r.error); return;} Navigator.of(context).popUntil((route)=>route.isFirst); }

  @override
  void dispose() {
    for (final c in [name, email, pw, cf]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(showBack: true, title: 'Create your account', subtitle: 'Join CityGuide in under a minute.', children: [
      TextField(controller: name, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: 'Full name', errorText: errs['name'])),
      const SizedBox(height: 14),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: 'Email', errorText: errs['email'])),
      const SizedBox(height: 14),
      PasswordField(controller: pw, label: 'Password', error: errs['password'], meter: true),
      Padding(padding: const EdgeInsets.only(top: 4, bottom: 12), child: Text('8+ characters with upper-case, lower-case and a number.', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor))),
      PasswordField(controller: cf, label: 'Confirm password', error: errs['confirm'], action: TextInputAction.done, onSubmitted: (_) => submit()),
      if(error!=null) Padding(padding: const EdgeInsets.only(top:8),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      const SizedBox(height: 18),
      FilledButton(onPressed: submit, child: const Text('Sign up')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Already registered? Log in')),
    ]);
  }
}

// ---------------------------------------------------------------- Forgot / reset password
class ForgotScreen extends StatefulWidget {
  final AppState state;
  const ForgotScreen({super.key, required this.state});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final email = TextEditingController(), code = TextEditingController(), pw = TextEditingController(), cf = TextEditingController();
  int stage = 1;
  String? demoCode, error, mail;

  @override
  void dispose() {
    for (final c in [email, code, pw, cf]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> send() async { setState(()=>error='Password reset email delivery is not configured on this server. Please contact the City Guide administrator to reset your password.'); }
  void reset() { setState(()=>error='Password reset is unavailable until email delivery is configured.'); }

  @override
  Widget build(BuildContext context) {
    final err = error == null ? <Widget>[] : [Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)))];
    if (stage == 1) {
      return _AuthScaffold(showBack: true, title: 'Reset your password', subtitle: 'Password reset is temporarily unavailable because email delivery is not configured.', children: [
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 14),
        ...err,
        FilledButton(onPressed: null, child: const Text('Reset unavailable')),
      ]);
    }
    return _AuthScaffold(showBack: true, title: 'Enter your code', subtitle: 'Email delivery is not configured for this deployment.', children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), border: Border.all(color: const Color(0xFFFCD34D)), borderRadius: BorderRadius.circular(12)),
        child: demoCode != null
            ? Column(children: [
                const Text('📧 Demo inbox: no mail server is connected in this frontend-only build, so your code is shown here:', style: TextStyle(color: Color(0xFF713F12))),
                const SizedBox(height: 6),
                SelectableText(demoCode!, style: const TextStyle(fontSize: 30, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFF713F12))),
              ])
            : const Text('Email delivery is not configured. Contact the City Guide administrator for help.', style: TextStyle(color: Color(0xFF713F12))),
      ),
      const SizedBox(height: 14),
      TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit code', counterText: '')),
      const SizedBox(height: 14),
      PasswordField(controller: pw, label: 'New password', meter: true),
      const SizedBox(height: 14),
      PasswordField(controller: cf, label: 'Confirm new password', action: TextInputAction.done),
      const SizedBox(height: 14),
      ...err,
      FilledButton(onPressed: reset, child: const Text('Reset password')),
      TextButton(onPressed: () => setState(() => stage = 1), child: const Text('Use a different email')),
    ]);
  }
}
