import 'package:flutter/material.dart';
import 'package:gestcare_app/app_session.dart';
import 'package:gestcare_app/backend_api.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestcare_app/home_dashboard_data_source.dart';
import 'viacep_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSession.init();
  runApp(const GestCareApp());
}

String _formatBrazilianDate(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final day = normalized.day.toString().padLeft(2, '0');
  final month = normalized.month.toString().padLeft(2, '0');
  return '$day/$month/${normalized.year}';
}

Future<void> _syncAuthenticatedProfile(BackendApi api, String token) async {
  final profile = await api.profile(token);
  await AppSession.saveProfile(
    name: profile.name,
    email: profile.email,
    dueDate: profile.birthDate,
  );
}

class GestCareColors {
  static const Color deepTeal = Color(0xFF0C7A71);
  static const Color mint = Color(0xFFBEEDE1);
  static const Color softMint = Color(0xFFD9EEE9);
  static const Color cream = Color(0xFFF6EFE5);
  static const Color peach = Color(0xFFF8C9AF);
  static const Color coral = Color(0xFFF6AA8C);
  static const Color background = Color(0xFFF4F7F5);
  static const Color textPrimary = Color(0xFF173831);
  static const Color textMuted = Color(0xFF6B8A83);
}

class GestCareApp extends StatelessWidget {
  const GestCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme)
        .apply(
          bodyColor: GestCareColors.textPrimary,
          displayColor: GestCareColors.textPrimary,
        );

    return MaterialApp(
      title: 'Maternar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: GestCareColors.background,
        textTheme: textTheme,
        colorScheme: ColorScheme.fromSeed(
          seedColor: GestCareColors.deepTeal,
          primary: GestCareColors.deepTeal,
          secondary: GestCareColors.mint,
          surface: Colors.white,
        ),
      ),
      initialRoute: AppSession.isAuthenticated ? '/home' : '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainAppNavigation(),
        '/questionnaire': (context) => const QuestionnaireScreen(),
        '/processing': (context) => const ProfileProcessingScreen(),
        '/safe-path': (context) => const SafePathResultScreen(),
        '/high-alert': (context) => const HighAlertResultScreen(),
        '/daily-log': (context) => const DailyLogScreen(),
        '/education': (context) => const EducationalArticlesScreen(),
        '/baby-week': (context) => const BabyWeekPlannerScreen(),
        '/nutrition': (context) => const NutritionTipsScreen(),
        '/notifications': (context) => const NotificationCenterScreen(),
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FBF9), Color(0xFFEFF7F3)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              children: [
                const Spacer(),
                const _PregnancyWelcomeIllustration(),
                const SizedBox(height: 28),
                Text(
                  'Maternar',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: GestCareColors.deepTeal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Acompanhamento preventivo para\numa gestacao tranquila',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: GestCareColors.textMuted,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Criar Minha Conta',
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: Color(0x220C7A71)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    foregroundColor: GestCareColors.textMuted,
                  ),
                  child: const Text('Login'),
                ),
                const SizedBox(height: 18),
                Text(
                  'TERMOS DE USO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.4,
                    color: const Color(0xFFB1C1BA),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final BackendApi _api = BackendApi();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isFormattingPhone = false;
  bool _isSubmitting = false;

  // Raça/cor e escolaridade conforme DATASUS (obrigatórios no backend)
  int _raceColor = 4; // 4 = Parda
  int _educationLevel = 4; // 4 = Médio completo

  static const Map<int, String> _raceColorLabels = {
    1: 'Branca',
    2: 'Preta',
    3: 'Amarela',
    4: 'Parda',
    5: 'Indigena',
  };

  static const Map<int, String> _educationLevelLabels = {
    1: 'Sem escolaridade',
    2: 'Fundamental incompleto',
    3: 'Fundamental completo',
    4: 'Medio completo',
    5: 'Superior completo',
  };

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _specialCharRegex = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
  static final RegExp _numberRegex = RegExp(r'\d');
  static final RegExp _upperRegex = RegExp(r'[A-Z]');
  static final RegExp _lowerRegex = RegExp(r'[a-z]');

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasSpecialChar =>
      _specialCharRegex.hasMatch(_passwordController.text);
  bool get _hasNumber => _numberRegex.hasMatch(_passwordController.text);
  bool get _hasUpperAndLower =>
      _upperRegex.hasMatch(_passwordController.text) &&
      _lowerRegex.hasMatch(_passwordController.text);

  int get _passwordScore {
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasSpecialChar) score++;
    if (_hasNumber) score++;
    if (_hasUpperAndLower) score++;
    return score;
  }

  String get _passwordStrengthLabel {
    if (_passwordController.text.isEmpty) return 'Nao definida';
    if (_passwordScore <= 1) return 'Fraca';
    if (_passwordScore <= 3) return 'Media';
    return 'Forte';
  }

  Color get _passwordStrengthColor {
    if (_passwordController.text.isEmpty) return const Color(0xFFB8C7C2);
    if (_passwordScore <= 1) return const Color(0xFFE87B73);
    if (_passwordScore <= 3) return const Color(0xFFE2A93B);
    return GestCareColors.deepTeal;
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _phoneController.addListener(_onPhoneChanged);
    _zipCodeController.addListener(_onZipChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _phoneController.removeListener(_onPhoneChanged);
    _zipCodeController.removeListener(_onZipChanged);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _zipCodeController.dispose();
    _streetController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _birthDateController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPhoneChanged() {
    if (_isFormattingPhone) return;

    final digitsOnly = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final clamped = digitsOnly.length > 11
        ? digitsOnly.substring(0, 11)
        : digitsOnly;
    final formatted = _formatPhone(clamped);

    _isFormattingPhone = true;
    _phoneController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormattingPhone = false;
  }

  String _formatPhone(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 2) return '($digits';

    final ddd = digits.substring(0, 2);
    final rest = digits.substring(2);

    if (rest.length <= 4) {
      return '($ddd) $rest';
    }

    if (digits.length <= 10) {
      final first = rest.substring(0, 4);
      final second = rest.substring(4);
      return second.isEmpty ? '($ddd) $first' : '($ddd) $first-$second';
    }

    final first = rest.substring(0, 5);
    final second = rest.substring(5);
    return second.isEmpty ? '($ddd) $first' : '($ddd) $first-$second';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final minimumDate = DateTime(2026, 1, 1);
    final maximumDate = DateTime(2099, 12, 31);
    final initial = now.isBefore(minimumDate) ? minimumDate : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minimumDate,
      lastDate: maximumDate,
      helpText: 'Data prevista do parto',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
    );

    if (picked == null) return;

    final day = picked.day.toString().padLeft(2, '0');
    final month = picked.month.toString().padLeft(2, '0');
    final year = picked.year.toString();
    _birthDateController.text = '$day/$month/$year';
  }

  String _toIsoDate(String brDate) {
    final parts = brDate.split('/');
    if (parts.length != 3) {
      throw const FormatException('Data invalida');
    }

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null || year < 2026) {
      throw const FormatException('Data invalida');
    }

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Data invalida');
    }

    final isoMonth = parsed.month.toString().padLeft(2, '0');
    final isoDay = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$isoMonth-$isoDay';
  }

  String? _validateZip(String? value) {
    final text = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return 'Informe seu CEP.';
    if (text.length != 8) return 'CEP invalido. Use 8 digitos.';
    return null;
  }

  bool _isLookingUpCep = false;
  final ViaCepService _viaCep = ViaCepService();
  bool _autoFillCep = true;

  void _onZipChanged() {
    final digits = _zipCodeController.text.replaceAll(RegExp(r'\D'), '');
    if (_autoFillCep && digits.length == 8 && !_isLookingUpCep) {
      _lookupCep(digits);
    }
    if (digits.length < 8) {
      _streetController.text = '';
      _neighborhoodController.text = '';
      _cityController.text = '';
    }
  }

  Future<void> _lookupCep(String digits) async {
    _isLookingUpCep = true;
    try {
      final data = await _viaCep.fetch(digits);
      if (mounted) {
        setState(() {
          _streetController.text = data['street'] ?? '';
          _neighborhoodController.text = data['neighborhood'] ?? '';
          _cityController.text = '${data['city'] ?? ''} ${data['state'] ?? ''}'.trim();
        });
      }
    } on ApiClientException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao consultar ViaCEP.')));
      }
    } finally {
      _isLookingUpCep = false;
    }
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe seu nome completo.';
    if (text.length < 3) return 'Nome muito curto.';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe seu e-mail.';
    if (!_emailRegex.hasMatch(text)) return 'E-mail invalido.';
    return null;
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Informe seu telefone.';
    if (digits.length < 10) return 'Telefone incompleto.';
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Crie uma senha.';
    if (text.length < 8) return 'A senha precisa ter no minimo 8 caracteres.';
    if (!_specialCharRegex.hasMatch(text)) {
      return 'Inclua ao menos 1 caractere especial.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Confirme sua senha.';
    if (value != _passwordController.text) return 'As senhas nao conferem.';
    return null;
  }

  String? _validateBirthDate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe a data prevista do parto.';

    final parts = text.split('/');
    if (parts.length != 3) return 'Data invalida. Use DD/MM/AAAA.';

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) {
      return 'Data invalida. Use DD/MM/AAAA.';
    }

    if (year < 2026) {
      return 'Use uma data a partir de 2026.';
    }

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return 'Data invalida. Use DD/MM/AAAA.';
    }

    return null;
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final birthDateIso = _toIsoDate(_birthDateController.text.trim());
      final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      await _api.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        birthDateIso: birthDateIso,
        zipCode: _zipCodeController.text.replaceAll(RegExp(r'\D'), ''),
        raceColor: _raceColor,
        educationLevel: _educationLevel,
        phone: phone.isNotEmpty ? phone : null,
      );

      final loginResult = await _api.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await AppSession.saveToken(loginResult.accessToken);
      try {
        await _syncAuthenticatedProfile(_api, loginResult.accessToken);
      } catch (_) {
        await AppSession.saveProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          dueDate: DateTime.parse(birthDateIso),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada com sucesso!')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on ApiClientException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data prevista do parto invalida.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Conta'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Vamos comecar sua jornada',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preencha seus dados para acessar o acompanhamento personalizado.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: GestCareColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              LabeledField(
                label: 'Nome completo',
                child: TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Ana Clara Sousa',
                  ),
                ),
              ),
              LabeledField(
                label: 'E-mail',
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  decoration: const InputDecoration(
                    hintText: 'seuemail@exemplo.com',
                  ),
                ),
              ),
              LabeledField(
                label: 'Telefone',
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: _validatePhone,
                  decoration: const InputDecoration(
                    hintText: '(11) 99999-8888',
                  ),
                ),
              ),
              LabeledField(
                label: 'CEP',
                child: TextFormField(
                  controller: _zipCodeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: _validateZip,
                  decoration: InputDecoration(
                    hintText: 'Ex: 01001-000',
                    suffixIcon: _isLookingUpCep
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            onPressed: () {
                              final digits = _zipCodeController.text.replaceAll(RegExp(r'\D'), '');
                              if (digits.length == 8) _lookupCep(digits);
                            },
                            icon: const Icon(Icons.search),
                          ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Preenchimento automático'),
                  Switch(
                    value: _autoFillCep,
                    onChanged: (v) => setState(() => _autoFillCep = v),
                  ),
                ],
              ),
              if (_streetController.text.isNotEmpty || _neighborhoodController.text.isNotEmpty || _cityController.text.isNotEmpty) ...[
                LabeledField(
                  label: 'Logradouro',
                  child: TextFormField(
                    controller: _streetController,
                    readOnly: true,
                    decoration: const InputDecoration(hintText: ''),
                  ),
                ),
                LabeledField(
                  label: 'Bairro',
                  child: TextFormField(
                    controller: _neighborhoodController,
                    readOnly: true,
                    decoration: const InputDecoration(hintText: ''),
                  ),
                ),
                LabeledField(
                  label: 'Cidade/UF',
                  child: TextFormField(
                    controller: _cityController,
                    readOnly: true,
                    decoration: const InputDecoration(hintText: ''),
                  ),
                ),
              ],
              LabeledField(
                label: 'Data prevista do parto',
                child: TextFormField(
                  controller: _birthDateController,
                  readOnly: true,
                  onTap: _pickBirthDate,
                  textInputAction: TextInputAction.next,
                  validator: _validateBirthDate,
                  decoration: InputDecoration(
                    hintText: 'Ex: 20/09/2026',
                    suffixIcon: IconButton(
                      onPressed: _pickBirthDate,
                      icon: const Icon(Icons.calendar_month),
                    ),
                  ),
                ),
              ),
              LabeledField(
                label: 'Raca/cor',
                child: DropdownButtonFormField<int>(
                  value: _raceColor,
                  decoration: const InputDecoration(hintText: 'Selecione'),
                  items: _raceColorLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _raceColor = v ?? 4),
                ),
              ),
              LabeledField(
                label: 'Escolaridade',
                child: DropdownButtonFormField<int>(
                  value: _educationLevel,
                  decoration: const InputDecoration(hintText: 'Selecione'),
                  items: _educationLevelLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _educationLevel = v ?? 4),
                ),
              ),
              LabeledField(
                label: 'Senha',
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    hintText: 'Crie uma senha segura',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _hidePassword = !_hidePassword);
                      },
                      icon: Icon(
                        _hidePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Regras da senha',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PasswordRuleTile(
                      passed: _hasMinLength,
                      label: 'Minimo de 8 caracteres',
                    ),
                    const SizedBox(height: 6),
                    _PasswordRuleTile(
                      passed: _hasSpecialChar,
                      label: 'Pelo menos 1 caractere especial',
                    ),
                    const SizedBox(height: 6),
                    _PasswordRuleTile(
                      passed: _hasNumber,
                      label: 'Pelo menos 1 numero',
                    ),
                    const SizedBox(height: 6),
                    _PasswordRuleTile(
                      passed: _hasUpperAndLower,
                      label: 'Letras maiusculas e minusculas',
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      minHeight: 8,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      value: _passwordController.text.isEmpty
                          ? 0
                          : _passwordScore / 4,
                      color: _passwordStrengthColor,
                      backgroundColor: const Color(0xFFE6EEEA),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Forca da senha: $_passwordStrengthLabel',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _passwordStrengthColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              LabeledField(
                label: 'Confirmar senha',
                child: TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _hideConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirmPassword,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Repita sua senha',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(
                          () => _hideConfirmPassword = !_hideConfirmPassword,
                        );
                      },
                      icon: Icon(
                        _hideConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: _isSubmitting
                    ? 'Cadastrando...'
                    : 'Finalizar Cadastro',
                onPressed: _isSubmitting ? () {} : _submit,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final BackendApi _api = BackendApi();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _isLoading = false;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe seu e-mail.';
    if (!_emailRegex.hasMatch(text)) return 'E-mail invalido.';
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Informe sua senha.';
    if (text.length < 6) return 'Senha invalida.';
    return null;
  }

  Future<void> _signIn() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final result = await _api.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await AppSession.saveToken(result.accessToken);
      try {
        await _syncAuthenticatedProfile(_api, result.accessToken);
      } catch (_) {
        // Mantem a sessao autenticada mesmo se o perfil nao puder ser carregado neste momento.
      }

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on ApiClientException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Bem-vinda de volta',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Entre com seu e-mail e senha para continuar sua jornada.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: GestCareColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              LabeledField(
                label: 'E-mail',
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  decoration: const InputDecoration(
                    hintText: 'seuemail@exemplo.com',
                  ),
                ),
              ),
              LabeledField(
                label: 'Senha',
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.done,
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    hintText: 'Digite sua senha',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _hidePassword = !_hidePassword);
                      },
                      icon: Icon(
                        _hidePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: _isLoading ? 'Entrando...' : 'Entrar',
                onPressed: _isLoading ? () {} : _signIn,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.pushNamed(context, '/signup'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Criar conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRuleTile extends StatelessWidget {
  const _PasswordRuleTile({required this.passed, required this.label});

  final bool passed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.radio_button_unchecked,
          color: passed ? GestCareColors.deepTeal : GestCareColors.textMuted,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: passed
                ? GestCareColors.textPrimary
                : GestCareColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class MainAppNavigation extends StatefulWidget {
  const MainAppNavigation({super.key});

  @override
  State<MainAppNavigation> createState() => _MainAppNavigationState();
}

class _MainAppNavigationState extends State<MainAppNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomeDashboardScreen(),
    const HealthMetricsScreen(),
    const ConsultationHistoryScreen(),
    const ProfileSettingsScreen(),
  ];

  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFEAF1EE),
        elevation: 8,
        unselectedItemColor: const Color(0xFF97ABA4),
        selectedItemColor: GestCareColors.deepTeal,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Saude'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Consultas',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class HomeDashboardScreen extends StatefulWidget {
  HomeDashboardScreen({
    HomeDashboardDataSource? dataSource,
    super.key,
  }) : dataSource = dataSource ?? ApiHomeDashboardDataSource();

  final HomeDashboardDataSource dataSource;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late Future<HomeDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.dataSource.fetch();
  }

  void _reload() {
    setState(() {
      _dashboardFuture = widget.dataSource.fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<HomeDashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nao foi possivel carregar os dados da Home.'),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _reload,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            final babySize = _babySizeForWeek(data.currentWeek);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              children: [
                _HomeGreetingHeader(
                  userName: data.userName,
                  currentWeek: data.currentWeek,
                  onNotificationsTap: () =>
                      Navigator.pushNamed(context, '/notifications'),
                ),
                const SizedBox(height: 20),
                _HomeHealthProfileCard(
                  onQuestionnaireTap: () =>
                      Navigator.pushNamed(context, '/questionnaire'),
                ),
                const SizedBox(height: 16),
                _HomeStatusCardsRow(
                  currentWeek: data.currentWeek,
                  babySizeName: babySize.name,
                  babySizeIcon: babySize.icon,
                  daysToBirth: data.daysToBirth,
                  onBabySizeTap: () =>
                      Navigator.pushNamed(context, '/baby-week'),
                ),
                const SizedBox(height: 16),
                _HomeDailyTipsSection(
                  tips: data.dailyTips,
                  onSeeAllTap: () => Navigator.pushNamed(context, '/education'),
                  onTipTap: (tip) {
                    if (tip.routeName != null) {
                      Navigator.pushNamed(context, tip.routeName!);
                    }
                  },
                ),
                const SizedBox(height: 16),
                _HomeQuickActionsSection(
                  actions: data.quickActions,
                  onActionTap: (action) {
                    Navigator.pushNamed(context, action.routeName);
                  },
                ),
                const SizedBox(height: 18),
                _HomeRecommendedArticleCard(
                  title: data.recommendedArticleTitle,
                  onTap: () => Navigator.pushNamed(
                    context,
                    data.recommendedArticleRoute,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeGreetingHeader extends StatelessWidget {
  const _HomeGreetingHeader({
    required this.userName,
    required this.currentWeek,
    required this.onNotificationsTap,
  });

  final String userName;
  final int currentWeek;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: GestCareColors.peach,
          child: Icon(Icons.face, color: GestCareColors.deepTeal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Oi, $userName!',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '$currentWeek semanas de gestação',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: GestCareColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNotificationsTap,
          tooltip: 'Abrir notificacoes',
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _HomeHealthProfileCard extends StatelessWidget {
  const _HomeHealthProfileCard({required this.onQuestionnaireTap});

  final VoidCallback onQuestionnaireTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFC4F3E8), Color(0xFF8CDDC9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x55FFFFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'SEU PERFIL ATUAL',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: GestCareColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Como voce esta\nse sentindo hoje?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Compartilhe sintomas para receber orientacao especializada.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Responder questionario de saude',
            icon: Icons.arrow_forward,
            onPressed: onQuestionnaireTap,
          ),
        ],
      ),
    );
  }
}

class _HomeStatusCardsRow extends StatelessWidget {
  const _HomeStatusCardsRow({
    required this.currentWeek,
    required this.babySizeName,
    required this.babySizeIcon,
    required this.daysToBirth,
    required this.onBabySizeTap,
  });

  final int currentWeek;
  final String babySizeName;
  final IconData babySizeIcon;
  final int daysToBirth;
  final VoidCallback onBabySizeTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TinyStatusCard(
            title: '$currentWeek semanas',
            value: 'Tamanho de $babySizeName',
            icon: babySizeIcon,
            onTap: onBabySizeTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TinyStatusCard(
            title: 'Dias para o parto',
            value: '$daysToBirth dias',
            icon: Icons.favorite,
            warm: true,
          ),
        ),
      ],
    );
  }
}

class _HomeDailyTipsSection extends StatelessWidget {
  const _HomeDailyTipsSection({
    required this.tips,
    required this.onSeeAllTap,
    required this.onTipTap,
  });

  final List<HomeTipData> tips;
  final VoidCallback onSeeAllTap;
  final ValueChanged<HomeTipData> onTipTap;

  IconData _iconForKey(String key) {
    switch (key) {
      case 'water':
        return Icons.water_drop;
      case 'meditation':
        return Icons.self_improvement;
      case 'nutrition':
        return Icons.restaurant_menu;
      default:
        return Icons.tips_and_updates;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dicas de hoje',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(onPressed: onSeeAllTap, child: const Text('Ver tudo')),
          ],
        ),
        for (final tip in tips) ...[
          TipTile(
            icon: _iconForKey(tip.iconKey),
            title: tip.title,
            subtitle: tip.subtitle,
            warm: tip.warm,
            onTap: () => onTipTap(tip),
          ),
          if (tip != tips.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HomeQuickActionsSection extends StatelessWidget {
  const _HomeQuickActionsSection({
    required this.actions,
    required this.onActionTap,
  });

  final List<HomeQuickActionData> actions;
  final ValueChanged<HomeQuickActionData> onActionTap;

  IconData _iconForKey(String key) {
    switch (key) {
      case 'diary':
        return Icons.edit_note;
      case 'library':
        return Icons.menu_book;
      default:
        return Icons.widgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (int index = 0; index < actions.length; index++) ...[
          Expanded(
            child: QuickActionCard(
              icon: _iconForKey(actions[index].iconKey),
              title: actions[index].title,
              subtitle: actions[index].subtitle,
              onTap: () => onActionTap(actions[index]),
            ),
          ),
          if (index < actions.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _HomeRecommendedArticleCard extends StatelessWidget {
  const _HomeRecommendedArticleCard({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 145,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF0A1A1F), Color(0xFF283A40)],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ARTIGO RECOMENDADO',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF9FB5BC),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HealthMetricsScreen extends StatelessWidget {
  const HealthMetricsScreen({super.key});

  void _showManualEntrySheet(BuildContext context) {
    final valueController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adicionar medicao',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text('Valor da medicao'),
              const SizedBox(height: 8),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(
                  hintText: 'Ex: 118/76 ou 68.2',
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Salvar',
                onPressed: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        valueController.text.isEmpty
                            ? 'Medicao salva.'
                            : 'Medicao ${valueController.text} salva.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metricas de Saude'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              'Acompanhe seu progresso',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _MetricCard(
              title: 'Pressao Arterial',
              value: '120/80 mmHg',
              subtitle: 'Ultima medicao: Hoje',
              icon: Icons.favorite,
              isNormal: true,
            ),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Peso',
              value: '68.5 kg',
              subtitle: 'Ganho de 8.5kg na gestacao',
              icon: Icons.scale,
              isNormal: true,
            ),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Glicemia',
              value: '95 mg/dL',
              subtitle: 'Ultima medicao: 2 dias atras',
              icon: Icons.trending_up,
              isNormal: true,
            ),
            const SizedBox(height: 12),
            _MetricCard(
              title: 'Tamanho do Bebe',
              value: '30.5 cm',
              subtitle: 'Peso estimado: 700g',
              icon: Icons.child_care,
              isNormal: true,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Adicionar Medicao Manual',
              icon: Icons.add,
              onPressed: () => _showManualEntrySheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool isNormal;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.isNormal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNormal ? GestCareColors.mint : GestCareColors.coral,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isNormal
                ? const Color(0xFFE5F2FF)
                : const Color(0xFFFFE8DA),
            child: Icon(
              icon,
              color: isNormal ? GestCareColors.deepTeal : GestCareColors.coral,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: GestCareColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: GestCareColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConsultationHistoryScreen extends StatefulWidget {
  const ConsultationHistoryScreen({super.key});

  @override
  State<ConsultationHistoryScreen> createState() =>
      _ConsultationHistoryScreenState();
}

class _ConsultationHistoryScreenState extends State<ConsultationHistoryScreen> {
  final BackendApi _api = BackendApi();
  List<QuestionnaireRecord>? _records;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final token = AppSession.token;
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final pregnancies = await _api.getPregnancies(token);
      final active = pregnancies.where((p) => p.isActive).toList();
      if (active.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final records =
          await _api.getQuestionnaires(token: token, pregnancyId: active.first.id);
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } on ApiClientException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Nao foi possivel carregar o historico.';
        _isLoading = false;
      });
    }
  }

  Color _hexToColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return GestCareColors.mint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historico de Avaliações'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off,
                              size: 48, color: GestCareColors.textMuted),
                          const SizedBox(height: 12),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _error = null;
                              });
                              _loadHistory();
                            },
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  )
                : (_records == null || _records!.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.assignment_outlined,
                                  size: 56, color: GestCareColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhuma avaliacao registrada ainda.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: GestCareColors.textMuted),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Preencha o questionario para ver seu historico aqui.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          Text(
                            'Historico de classificacoes',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          for (final record in _records!) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border(
                                  left: BorderSide(
                                    color: record.hexColor != null
                                        ? _hexToColor(record.hexColor!)
                                        : GestCareColors.mint,
                                    width: 4,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        record.clusterName ?? 'Em processamento',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        _formatBrazilianDate(record.responseDate),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: GestCareColors.textMuted),
                                      ),
                                    ],
                                  ),
                                  if (record.riskLevel != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Risco: ${record.riskLevel}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: GestCareColors.textMuted),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    'Peso: ${record.currentWeight.toStringAsFixed(1)} kg'
                                    '${record.calculatedImc != null ? '   IMC: ${record.calculatedImc!.toStringAsFixed(1)}' : ''}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (record.recommendations != null &&
                                      record.recommendations!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      record.recommendations!.first,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: GestCareColors.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            );
  }
}


class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final BackendApi _api = BackendApi();

  bool _isLoading = true;
  String _name = 'Gestante';
  String _email = '';
  DateTime? _dueDate;
  String? _phone;
  double? _height;
  double? _preWeight;
  int _raceColor = 1;
  int _educationLevel = 1;

  static const Map<int, String> _raceColorLabels = {
    1: 'Branca',
    2: 'Preta',
    3: 'Amarela',
    4: 'Parda',
    5: 'Indigena',
  };

  static const Map<int, String> _educationLevelLabels = {
    1: 'Sem escolaridade',
    2: 'Fundamental incompleto',
    3: 'Fundamental completo',
    4: 'Medio completo',
    5: 'Superior completo',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final token = AppSession.token;
      if (token != null) {
        final profile = await _api.profile(token);
        await AppSession.saveProfile(
          name: profile.name,
          email: profile.email,
          dueDate: profile.birthDate,
        );
        if (mounted) {
          setState(() {
            _name = profile.name;
            _email = profile.email;
            _dueDate = profile.birthDate;
            _phone = profile.phone;
            _height = profile.height;
            _preWeight = profile.preGestationalWeight;
            _raceColor = profile.raceColor;
            _educationLevel = profile.educationLevel;
          });
        }
      } else {
        setState(() {
          _name = AppSession.profileName ?? _name;
          _email = AppSession.profileEmail ?? _email;
          _dueDate = AppSession.dueDate;
        });
      }
    } catch (_) {
      setState(() {
        _name = AppSession.profileName ?? _name;
        _email = AppSession.profileEmail ?? _email;
        _dueDate = AppSession.dueDate;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sair da conta'),
          content: const Text('Deseja encerrar a sessao agora?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await AppSession.clear();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  Future<void> _openEditProfileDialog() async {
    final nameController = TextEditingController(text: _name);
    final phoneController = TextEditingController(text: _phone ?? '');
    final heightController = TextEditingController(
      text: _height != null ? _height!.toStringAsFixed(2) : '',
    );
    final preWeightController = TextEditingController(
      text: _preWeight != null ? _preWeight!.toStringAsFixed(1) : '',
    );
    final formKey = GlobalKey<FormState>();
    var isSubmitting = false;

    String? validateName(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return 'Informe o nome.';
      if (text.length < 3) return 'Nome muito curto.';
      return null;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> saveChanges() async {
              final isValid = formKey.currentState?.validate() ?? false;
              if (!isValid || isSubmitting) return;

              setDialogState(() => isSubmitting = true);

              try {
                final token = AppSession.token;
                if (token != null) {
                  final heightVal = double.tryParse(
                      heightController.text.replaceAll(',', '.'));
                  final preWeightVal = double.tryParse(
                      preWeightController.text.replaceAll(',', '.'));
                  final updated = await _api.updateProfile(
                    token: token,
                    name: nameController.text.trim(),
                    phone: phoneController.text.isNotEmpty
                        ? phoneController.text
                        : null,
                    height: heightVal,
                    preGestationalWeight: preWeightVal,
                  );
                  await AppSession.saveProfile(
                    name: updated.name,
                    email: updated.email,
                    dueDate: updated.birthDate,
                  );
                  if (!mounted) return;
                  setState(() {
                    _name = updated.name;
                    _email = updated.email;
                    _dueDate = updated.birthDate;
                    _phone = updated.phone;
                    _height = updated.height;
                    _preWeight = updated.preGestationalWeight;
                  });
                } else {
                  await AppSession.saveProfile(
                    name: nameController.text.trim(),
                    email: _email,
                    dueDate: _dueDate ?? DateTime.now(),
                  );
                  if (!mounted) return;
                  setState(() => _name = nameController.text.trim());
                }
              } on ApiClientException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.message)));
              } finally {
                setDialogState(() => isSubmitting = false);
              }

              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }

            return AlertDialog(
              title: const Text('Editar perfil'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        validator: validateName,
                        decoration: const InputDecoration(labelText: 'Nome'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefone (opcional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Altura em metros (ex: 1.65)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: preWeightController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Peso pre-gestacional em kg',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: isSubmitting ? null : saveChanges,
                  child: Text(isSubmitting ? 'Salvando...' : 'Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentWeek = AppSession.currentWeek ?? 24;
    final daysToBirth = AppSession.daysToBirth ?? 112;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: GestCareColors.peach,
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: GestCareColors.deepTeal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: GestCareColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _openEditProfileDialog,
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar perfil'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingRow(
              icon: Icons.phone,
              title: 'Telefone',
              subtitle: (_phone != null && _phone!.isNotEmpty)
                  ? _phone!
                  : 'Nao informado',
            ),
            _SettingRow(
              icon: Icons.height,
              title: 'Altura',
              subtitle:
                  _height != null ? '${_height!.toStringAsFixed(2)} m' : 'Nao informada',
            ),
            _SettingRow(
              icon: Icons.monitor_weight,
              title: 'Peso pre-gestacional',
              subtitle: _preWeight != null
                  ? '${_preWeight!.toStringAsFixed(1)} kg'
                  : 'Nao informado',
            ),
            _SettingRow(
              icon: Icons.diversity_3,
              title: 'Raca/cor',
              subtitle: _raceColorLabels[_raceColor] ?? 'Nao informada',
            ),
            _SettingRow(
              icon: Icons.school,
              title: 'Escolaridade',
              subtitle: _educationLevelLabels[_educationLevel] ?? 'Nao informada',
            ),
            const SizedBox(height: 24),
            Text(
              'Gestacao atual',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _SettingRow(
              icon: Icons.calendar_month,
              title: 'Data prevista do parto',
              subtitle: _dueDate == null
                  ? 'Nao informada'
                  : _formatBrazilianDate(_dueDate!),
            ),
            _SettingRow(
              icon: Icons.timeline,
              title: 'Semanas de gestacao',
              subtitle: '$currentWeek semanas',
            ),
            _SettingRow(
              icon: Icons.hourglass_bottom,
              title: 'Dias para o parto',
              subtitle: '$daysToBirth dias',
            ),
            const SizedBox(height: 24),
            Text(
              'Preferencias',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _PreferenceToggle(title: 'Notificacoes', enabled: true),
            _PreferenceToggle(title: 'Lembretes de Consultas', enabled: true),
            _PreferenceToggle(title: 'Dicas Diarias', enabled: false),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => _confirmLogout(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: GestCareColors.coral),
              ),
              child: const Text('Sair da Conta'),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyLogScreen extends StatefulWidget {
  const DailyLogScreen({super.key});

  @override
  State<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends State<DailyLogScreen> {
  final TextEditingController _noteController = TextEditingController();
  final Set<String> _selectedSymptoms = {};
  final List<Map<String, String>> _entries = [
    {
      'date': '15 Abr',
      'mood': 'Calma',
      'symptoms': 'Leve cansaco',
      'note': 'Dormir melhor hoje.',
    },
  ];

  double _moodScore = 4;

  final List<String> _symptoms = const [
    'Nausea',
    'Cansaco',
    'Dor nas costas',
    'Inchaco',
    'Azia',
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _moodLabel(double score) {
    if (score <= 2) return 'Sensivel';
    if (score <= 3) return 'Estavel';
    if (score <= 4) return 'Calma';
    return 'Animada';
  }

  void _saveEntry() {
    final symptomText = _selectedSymptoms.isEmpty
        ? 'Sem sintomas'
        : _selectedSymptoms.join(', ');

    setState(() {
      _entries.insert(0, {
        'date': 'Hoje',
        'mood': _moodLabel(_moodScore),
        'symptoms': symptomText,
        'note': _noteController.text.trim().isEmpty
            ? 'Sem observacoes adicionais.'
            : _noteController.text.trim(),
      });
      _noteController.clear();
      _selectedSymptoms.clear();
      _moodScore = 4;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrada do diario registrada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diario de Sintomas'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Como voce esta hoje?',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Humor: ${_moodLabel(_moodScore)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Slider(
                    value: _moodScore,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    activeColor: GestCareColors.deepTeal,
                    label: _moodLabel(_moodScore),
                    onChanged: (value) => setState(() => _moodScore = value),
                  ),
                  const SizedBox(height: 8),
                  const Text('Sintomas percebidos'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _symptoms.map((symptom) {
                      final selected = _selectedSymptoms.contains(symptom);
                      return FilterChip(
                        label: Text(symptom),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedSymptoms.add(symptom);
                            } else {
                              _selectedSymptoms.remove(symptom);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Observacoes'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Ex: senti mais cansaco no fim da tarde.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Salvar no Diario',
                    onPressed: _saveEntry,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ultimos registros',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final entry in _entries)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry['date']} - ${entry['mood']}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry['symptoms']!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: GestCareColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(entry['note']!),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EducationalArticlesScreen extends StatefulWidget {
  const EducationalArticlesScreen({super.key});

  @override
  State<EducationalArticlesScreen> createState() =>
      _EducationalArticlesScreenState();
}

class _EducationalArticlesScreenState extends State<EducationalArticlesScreen> {
  String _selectedCategory = 'Todos';
  final Set<String> _savedArticles = {};

  final List<Map<String, String>> _articles = const [
    {
      'title': 'Sinais de alerta no terceiro trimestre',
      'category': 'Saude',
      'time': '6 min',
      'excerpt': 'Aprenda quais sinais precisam de avaliacao imediata.',
    },
    {
      'title': 'Rotina noturna para melhorar o sono',
      'category': 'Bem-estar',
      'time': '4 min',
      'excerpt': 'Ajustes simples para descansar melhor nessa fase.',
    },
    {
      'title': 'Plano de parto: o que conversar com a equipe',
      'category': 'Preparo',
      'time': '7 min',
      'excerpt': 'Defina preferencias e entenda opcoes com antecedencia.',
    },
  ];

  List<Map<String, String>> get _filteredArticles {
    if (_selectedCategory == 'Todos') return _articles;
    return _articles
        .where((article) => article['category'] == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    const categories = ['Todos', 'Saude', 'Bem-estar', 'Preparo'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca Educativa'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Conteudos para cada fase',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                return ChoiceChip(
                  label: Text(category),
                  selected: category == _selectedCategory,
                  onSelected: (_) {
                    setState(() => _selectedCategory = category);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            for (final article in _filteredArticles)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: GestCareColors.softMint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            article['category']!,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          article['time']!,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              final title = article['title']!;
                              if (_savedArticles.contains(title)) {
                                _savedArticles.remove(title);
                              } else {
                                _savedArticles.add(title);
                              }
                            });
                          },
                          icon: Icon(
                            _savedArticles.contains(article['title'])
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: GestCareColors.deepTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article['title']!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['excerpt']!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: GestCareColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Leitura completa em breve.'),
                          ),
                        );
                      },
                      child: const Text('Ler conteudo'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BabyWeekPlannerScreen extends StatefulWidget {
  const BabyWeekPlannerScreen({super.key});

  @override
  State<BabyWeekPlannerScreen> createState() => _BabyWeekPlannerScreenState();
}

class _BabyWeekPlannerScreenState extends State<BabyWeekPlannerScreen> {
  final TextEditingController _taskController = TextEditingController();

  int _currentWeek = AppSession.currentWeek ?? 24;

  bool _showAllTasks = false;

  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Tomar vitamina pre-natal', 'done': true},
    {'title': 'Agendar ultrassom desta semana', 'done': false},
    {'title': 'Beber pelo menos 2L de agua por dia', 'done': false},
    {'title': 'Separar exames para consulta', 'done': false},
  ];

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  int get _doneCount => _tasks.where((task) => task['done'] == true).length;

  _BabySizeInfo get _babySizeInfo => _babySizeForWeek(_currentWeek);
  String get _trimesterLabel => _trimesterForWeek(_currentWeek);
  String get _babySizeHeadline {
    if (_babySizeInfo.article == 'em') {
      return 'Seu bebe esta em ${_babySizeInfo.name}!';
    }

    return 'Seu bebe tem o\ntamanho de ${_babySizeInfo.article} ${_babySizeInfo.name}!';
  }

  int get _daysToBirthDisplay {
    final sessionWeek = AppSession.currentWeek;
    final sessionDaysToBirth = AppSession.daysToBirth;

    if (sessionWeek != null &&
        sessionDaysToBirth != null &&
        _currentWeek == sessionWeek) {
      return sessionDaysToBirth;
    }

    final estimated = 280 - (_currentWeek * 7);
    return estimated < 0 ? 0 : estimated;
  }

  List<Map<String, dynamic>> get _visibleTasks {
    if (_showAllTasks || _tasks.length <= 3) return _tasks;
    return _tasks.take(3).toList();
  }

  void _toggleTask(int index, bool? checked) {
    setState(() {
      _tasks[index]['done'] = checked ?? false;
    });
  }

  void _addTask() {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _tasks.add({'title': title, 'done': false});
      _taskController.clear();
      _showAllTasks = true;
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Nova tarefa adicionada.')));
  }

  void _openAddTaskDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Adicionar tarefa'),
          content: TextField(
            controller: _taskController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ex: Caminhar 20 minutos',
            ),
            onSubmitted: (_) => _addTask(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _taskController.clear();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(onPressed: _addTask, child: const Text('Adicionar')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Semana do Bebe'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: GestCareColors.softMint,
                    child: const Icon(
                      Icons.calendar_month,
                      color: GestCareColors.deepTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voce esta com $_currentWeek semanas',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$_trimesterLabel / faltam $_daysToBirthDisplay dias',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: GestCareColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajustar semana da gestacao',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: GestCareColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Slider(
                    min: 1,
                    max: 40,
                    divisions: 39,
                    activeColor: GestCareColors.deepTeal,
                    value: _currentWeek.toDouble(),
                    label: '$_currentWeek semanas',
                    onChanged: (value) {
                      setState(() => _currentWeek = value.round());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF2E4), Color(0xFFFFE8CF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tamanho do bebe',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: GestCareColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _babySizeHeadline,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: _FruitIllustration(
                      info: _babySizeInfo,
                      week: _currentWeek,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Dimensoes do bebe',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF3CA055),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _BabyDimensionItem(
                          label: 'Comprimento',
                          value: _babySizeInfo.lengthText,
                          helperText: _babySizeInfo.lengthHelper,
                        ),
                      ),
                      const SizedBox(
                        height: 48,
                        child: VerticalDivider(color: Color(0xFFE0E0E0)),
                      ),
                      Expanded(
                        child: _BabyDimensionItem(
                          label: 'Peso',
                          value: _babySizeInfo.weightText,
                        ),
                      ),
                      const SizedBox(
                        height: 48,
                        child: VerticalDivider(color: Color(0xFFE0E0E0)),
                      ),
                      Expanded(
                        child: _BabyDimensionItem(
                          label: 'Do tamanho de',
                          value: _babySizeInfo.name,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suas tarefas da semana',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _showAllTasks = !_showAllTasks);
                  },
                  child: Text(_showAllTasks ? 'Ver menos' : 'Ver todas'),
                ),
              ],
            ),
            Text(
              'Concluidas: $_doneCount de ${_tasks.length}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: GestCareColors.textMuted),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              minHeight: 7,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              value: _tasks.isEmpty ? 0 : _doneCount / _tasks.length,
              color: GestCareColors.deepTeal,
              backgroundColor: const Color(0xFFE3ECE8),
            ),
            const SizedBox(height: 12),
            for (final task in _visibleTasks)
              _WeeklyTaskCard(
                title: task['title'] as String,
                done: task['done'] as bool,
                onChanged: (value) {
                  final index = _tasks.indexOf(task);
                  _toggleTask(index, value);
                },
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openAddTaskDialog,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar outra tarefa'),
            ),
          ],
        ),
      ),
    );
  }
}

class NutritionTipsScreen extends StatelessWidget {
  const NutritionTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tips = [
      {
        'title': 'Cafe da manha nutritivo',
        'description':
            'Inclua 1 fonte de proteina (ovo, iogurte natural) e 1 fruta rica em fibras.',
        'icon': Icons.breakfast_dining,
      },
      {
        'title': 'Prato equilibrado no almoco',
        'description':
            'Metade do prato com legumes e verduras, 1 porcao de proteina magra e carboidrato integral.',
        'icon': Icons.lunch_dining,
      },
      {
        'title': 'Lanches inteligentes',
        'description':
            'Prefira castanhas, frutas e sanduiche natural em vez de ultraprocessados.',
        'icon': Icons.apple,
      },
      {
        'title': 'Hidratacao diaria',
        'description':
            'Meta de 2 a 3 litros de agua por dia, com pequenos goles ao longo do dia.',
        'icon': Icons.local_drink,
      },
      {
        'title': 'Seguranca alimentar',
        'description':
            'Evite alimentos crus de risco e mantenha boa higiene no preparo das refeicoes.',
        'icon': Icons.health_and_safety,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dicas de Nutricao'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Alimentacao para cada fase',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Sugestoes gerais para ajudar no bem-estar da gestacao. Elas nao substituem orientacao medica personalizada.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: GestCareColors.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F6F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: GestCareColors.deepTeal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Converse com sua nutricionista ou obstetra para ajustes conforme exames e sintomas.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final tip in tips)
              _NutritionTipCard(
                title: tip['title']! as String,
                description: tip['description']! as String,
                icon: tip['icon']! as IconData,
              ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Salvar lembrete de hidratacao',
              icon: Icons.alarm,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lembrete salvo. Em breve com notificacoes.'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Consulta amanha as 09:30',
      'message': 'Leve seus ultimos exames e cartao de pre-natal.',
      'read': false,
    },
    {
      'title': 'Hora da hidratacao',
      'message': 'Beba um copo de agua e marque no diario.',
      'read': false,
    },
    {
      'title': 'Novo conteudo recomendado',
      'message': 'Confira o artigo sobre plano de parto.',
      'read': true,
    },
  ];

  void _markAllAsRead() {
    setState(() {
      for (final item in _notifications) {
        item['read'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificacoes'),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Marcar lidas'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final item = _notifications[index];
            final isRead = item['read'] as bool;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isRead ? Colors.white : const Color(0xFFE9F4F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                onTap: () {
                  setState(() => item['read'] = true);
                },
                leading: CircleAvatar(
                  backgroundColor: isRead
                      ? const Color(0xFFECEFED)
                      : GestCareColors.mint,
                  child: Icon(
                    isRead ? Icons.notifications_none : Icons.notifications,
                    color: GestCareColors.deepTeal,
                  ),
                ),
                title: Text(
                  item['title'] as String,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                subtitle: Text(item['message'] as String),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF1F6F3),
            child: Icon(icon, color: GestCareColors.deepTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: GestCareColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceToggle extends StatefulWidget {
  final String title;
  final bool enabled;

  const _PreferenceToggle({required this.title, required this.enabled});

  @override
  State<_PreferenceToggle> createState() => _PreferenceToggleState();
}

class _PreferenceToggleState extends State<_PreferenceToggle> {
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Switch(
            value: _isEnabled,
            onChanged: (value) => setState(() => _isEnabled = value),
            activeColor: GestCareColors.deepTeal,
          ),
        ],
      ),
    );
  }
}

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _preWeightController = TextEditingController();
  final _heightController = TextEditingController();

  // Raça/cor conforme tabela DATASUS: 1=Branca 2=Preta 3=Amarela 4=Parda 5=Indígena
  int _racaCor = 4;
  // Escolaridade conforme DATASUS: 1=Sem escolaridade … 5=Superior completo
  int _escolaridade = 4;
  bool _firstPregnancy = true;

  @override
  void dispose() {
    _weightController.dispose();
    _preWeightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String? _validateWeight(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (n == null) return 'Informe um valor numerico.';
    if (n < 30 || n > 250) return 'Peso deve estar entre 30 e 250 kg.';
    return null;
  }

  String? _validatePreWeight(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (n == null) return 'Informe um valor numerico.';
    if (n < 30 || n > 250) return 'Peso deve estar entre 30 e 250 kg.';
    return null;
  }

  String? _validateHeight(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (n == null) return 'Informe um valor numerico.';
    if (n < 130 || n > 215) return 'Altura deve estar entre 130 e 215 cm.';
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final weight = double.parse(_weightController.text.replaceAll(',', '.'));
    final preWeight = double.parse(_preWeightController.text.replaceAll(',', '.'));
    final heightCm = double.parse(_heightController.text.replaceAll(',', '.'));
    final heightM = heightCm / 100.0;
    final imcPre = preWeight / (heightM * heightM);

    Navigator.pushNamed(
      context,
      '/processing',
      arguments: {
        'weight': weight,
        'height': heightM,
        'imcPreGestacional': imcPre,
        'racaCor': _racaCor,
        'escolaridade': _escolaridade,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Conhecendo Voce'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const LinearProgressIndicator(
                value: 0.4,
                minHeight: 6,
                borderRadius: BorderRadius.all(Radius.circular(8)),
                color: GestCareColors.deepTeal,
                backgroundColor: Color(0xFFE2ECE8),
              ),
              const SizedBox(height: 24),
              Text(
                'Sua jornada,\nseu cuidado.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Compartilhe alguns dados para recebermos orientacoes personalizadas para voce.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: GestCareColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              LabeledField(
                label: 'Peso atual (kg)',
                child: TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  validator: _validateWeight,
                  decoration: const InputDecoration(hintText: 'Ex: 72.5'),
                ),
              ),
              LabeledField(
                label: 'Peso antes de engravidar (kg)',
                child: TextFormField(
                  controller: _preWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  validator: _validatePreWeight,
                  decoration: const InputDecoration(hintText: 'Ex: 65.0'),
                ),
              ),
              LabeledField(
                label: 'Altura (cm)',
                child: TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  validator: _validateHeight,
                  decoration: const InputDecoration(hintText: 'Ex: 162'),
                ),
              ),
              LabeledField(
                label: 'Raca/cor',
                child: DropdownButtonFormField<int>(
                  value: _racaCor,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Branca')),
                    DropdownMenuItem(value: 2, child: Text('Preta')),
                    DropdownMenuItem(value: 3, child: Text('Amarela')),
                    DropdownMenuItem(value: 4, child: Text('Parda')),
                    DropdownMenuItem(value: 5, child: Text('Indigena')),
                  ],
                  onChanged: (v) => setState(() => _racaCor = v ?? 4),
                ),
              ),
              LabeledField(
                label: 'Escolaridade',
                child: DropdownButtonFormField<int>(
                  value: _escolaridade,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Sem escolaridade')),
                    DropdownMenuItem(value: 2, child: Text('Fundamental incompleto')),
                    DropdownMenuItem(value: 3, child: Text('Fundamental completo')),
                    DropdownMenuItem(value: 4, child: Text('Ensino medio')),
                    DropdownMenuItem(value: 5, child: Text('Ensino superior')),
                  ],
                  onChanged: (v) => setState(() => _escolaridade = v ?? 4),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Primeira gestacao?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Sim')),
                  ButtonSegment(value: false, label: Text('Nao')),
                ],
                selected: {_firstPregnancy},
                onSelectionChanged: (values) {
                  setState(() => _firstPregnancy = values.first);
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GestCareColors.softMint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: GestCareColors.deepTeal, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Seus dados sao usados apenas para personalizar seu acompanhamento. Nao compartilhamos com terceiros.',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: GestCareColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Voltar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Analisar Perfil',
                      icon: Icons.arrow_forward,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileProcessingScreen extends StatefulWidget {
  const ProfileProcessingScreen({super.key});

  @override
  State<ProfileProcessingScreen> createState() =>
      _ProfileProcessingScreenState();
}

class _ProfileProcessingScreenState extends State<ProfileProcessingScreen> {
  final BackendApi _api = BackendApi();
  bool _hasStarted = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStarted) {
      _hasStarted = true;
      _runClassification();
    }
  }

  Future<void> _runClassification() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    final token = AppSession.token;

    if (token == null || args == null) {
      _navigateToResult(isAlert: false, result: null);
      return;
    }

    final data = args as Map<String, dynamic>;

    try {
      final result = await _api.classify(
        token: token,
        weight: (data['weight'] as num).toDouble(),
        height: (data['height'] as num).toDouble(),
        imcPreGestacional: (data['imcPreGestacional'] as num).toDouble(),
        racaCor: data['racaCor'] as int,
        escolaridade: data['escolaridade'] as int,
      );
      if (!mounted) return;
      _navigateToResult(isAlert: result.isAlert, result: result);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      // Endpoint ainda nao implementado no backend: exibe erro e oferece continuar
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Nao foi possivel classificar o perfil. Tente novamente.');
    }
  }

  void _navigateToResult({required bool isAlert, required ClassificationResult? result}) {
    final route = isAlert ? '/high-alert' : '/safe-path';
    Navigator.pushReplacementNamed(context, route, arguments: result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maternar'),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.close)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              Container(
                height: 130,
                width: 130,
                decoration: BoxDecoration(
                  color: GestCareColors.deepTeal,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x440C7A71),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 24),
              Text(
                'Criando seu caminho\npersonalizado...',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Estamos cruzando suas informacoes para te dar as melhores orientacoes.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: GestCareColors.textMuted,
                ),
              ),
              const SizedBox(height: 22),
              const DotLoader(),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _errorMessage != null ? 0 : null,
                minHeight: 6,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                color: _errorMessage != null
                    ? GestCareColors.coral
                    : GestCareColors.deepTeal,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage != null ? 'AGUARDANDO' : 'PROCESSANDO',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: GestCareColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8DA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: GestCareColors.coral),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Ver Resultado Padrao',
                  onPressed: () => _navigateToResult(isAlert: false, result: null),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SafePathResultScreen extends StatelessWidget {
  const SafePathResultScreen({super.key});

  static const List<String> _defaultTips = [
    'Ritmo de hidratacao: mantenha consumo de agua constante para o bem-estar.',
    'Pausas de descanso: reserve pequenos periodos durante o dia para recuperar energia.',
    'Suplementacao ativa: siga o plano vitaminico recomendado no pre-natal.',
  ];

  @override
  Widget build(BuildContext context) {
    final result =
        ModalRoute.of(context)?.settings.arguments as ClassificationResult?;
    final tips = (result?.recomendacoes.isNotEmpty ?? false)
        ? result!.recomendacoes
        : _defaultTips;

    return ResultTemplate(
      title: 'Tudo pronto! Seu perfil esta definido.',
      subtitle:
          'Uma jornada de cuidado e serenidade comeca agora para voce e seu bebe.',
      badgeTitle: result?.clusterNomeApp ?? 'Caminho Seguro',
      badgeDescription: 'Parabens pelo acompanhamento da sua gestacao!',
      actionLabel: 'Ir para o Meu Painel',
      actionRoute: '/home',
      isAlert: false,
      tips: tips,
    );
  }
}

class HighAlertResultScreen extends StatelessWidget {
  const HighAlertResultScreen({super.key});

  static const List<String> _defaultTips = [
    'Monitore sua pressao arterial diariamente e anote em diario de saude.',
    'Fique atenta a inchacos repentinos nas maos e no rosto.',
    'Mantenha contato da sua obstetra e da rede de apoio sempre a mao.',
  ];

  @override
  Widget build(BuildContext context) {
    final result =
        ModalRoute.of(context)?.settings.arguments as ClassificationResult?;
    final tips = (result?.recomendacoes.isNotEmpty ?? false)
        ? result!.recomendacoes
        : _defaultTips;

    return ResultTemplate(
      title: 'Tudo pronto! Seu perfil esta definido.',
      subtitle: '',
      badgeTitle: result?.clusterNomeApp ?? 'Atencao Redobrada',
      badgeDescription:
          'Sua gestacao precisa de um pouco mais de cuidado. Estamos aqui para ajudar.',
      actionLabel: 'Entrar em Contato com a Rede de Apoio',
      actionRoute: '/home',
      isAlert: true,
      tips: tips,
    );
  }
}

class ResultTemplate extends StatelessWidget {
  const ResultTemplate({
    required this.title,
    required this.subtitle,
    required this.badgeTitle,
    required this.badgeDescription,
    required this.actionLabel,
    required this.actionRoute,
    required this.isAlert,
    required this.tips,
    super.key,
  });

  final String title;
  final String subtitle;
  final String badgeTitle;
  final String badgeDescription;
  final String actionLabel;
  final String actionRoute;
  final bool isAlert;
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isAlert ? 'Atencao Redobrada' : 'Caminho Seguro'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: GestCareColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isAlert
                    ? const Color(0xFFFFE1D1)
                    : const Color(0xFFE9F4F0),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isAlert
                        ? GestCareColors.peach
                        : GestCareColors.mint,
                    child: Icon(
                      isAlert ? Icons.flag : Icons.verified_user,
                      color: GestCareColors.deepTeal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    badgeTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: GestCareColors.deepTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badgeDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isAlert
                  ? 'Orientacoes Urgentinhas'
                  : 'Orientacoes Personalizadas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      isAlert
                          ? Icons.priority_high_rounded
                          : Icons.check_circle_rounded,
                      color: isAlert
                          ? GestCareColors.coral
                          : GestCareColors.deepTeal,
                    ),
                    title: Text(tip),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: actionLabel,
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  actionRoute,
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Revisar Respostas'),
            ),
          ],
        ),
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: GestCareColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class DotLoader extends StatelessWidget {
  const DotLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LoaderDot(opacity: 1),
        SizedBox(width: 8),
        LoaderDot(opacity: 0.7),
        SizedBox(width: 8),
        LoaderDot(opacity: 0.45),
      ],
    );
  }
}

class LoaderDot extends StatelessWidget {
  const LoaderDot({required this.opacity, super.key});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: GestCareColors.deepTeal,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class TipTile extends StatelessWidget {
  const TipTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.warm = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool warm;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title. $subtitle',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: warm
                ? const Color(0xFFFFE8DA)
                : const Color(0xFFE5F2FF),
            child: Icon(
              icon,
              color: warm ? GestCareColors.coral : GestCareColors.deepTeal,
            ),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _NutritionTipCard extends StatelessWidget {
  const _NutritionTipCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE8F6F1),
            child: Icon(icon, color: GestCareColors.deepTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: GestCareColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TinyStatusCard extends StatelessWidget {
  const TinyStatusCard({
    required this.title,
    required this.value,
    required this.icon,
    this.warm = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool warm;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$title: $value',
      child: Material(
        color: warm ? const Color(0xFFFFE0CC) : const Color(0xFFF1F6F3),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: GestCareColors.deepTeal),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: GestCareColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: GestCareColors.deepTeal),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: GestCareColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyTaskCard extends StatelessWidget {
  const _WeeklyTaskCard({
    required this.title,
    required this.done,
    required this.onChanged,
  });
  final String title;
  final bool done;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: CheckboxListTile(
        value: done,
        onChanged: onChanged,
        activeColor: GestCareColors.deepTeal,
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? GestCareColors.textMuted : GestCareColors.textPrimary,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}

class _BabyDimensionItem extends StatelessWidget {
  const _BabyDimensionItem({
    required this.label,
    required this.value,
    this.helperText,
  });

  final String label;
  final String value;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: GestCareColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (helperText != null && helperText != '-' && helperText!.isNotEmpty)
          Text(
            helperText!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: GestCareColors.textMuted,
            ),
          ),
      ],
    );
  }
}

class _BabySizeInfo {
  const _BabySizeInfo({
    required this.name,
    this.article = 'uma',
    this.illustrationEmoji,
    required this.lengthText,
    this.lengthHelper = 'da cabeca ao bumbum',
    required this.weightText,
    required this.icon,
    required this.kind,
    required this.primaryColor,
    required this.secondaryColor,
    required this.leafColor,
  });

  final String name;
  final String article;
  final String? illustrationEmoji;
  final String lengthText;
  final String lengthHelper;
  final String weightText;
  final IconData icon;
  final _FruitKind kind;
  final Color primaryColor;
  final Color secondaryColor;
  final Color leafColor;
}

_BabySizeInfo _babySizeForWeek(int currentWeek) {
  const weeklyData = <int, _BabySizeInfo>{
    1: _BabySizeInfo(
      name: 'desenvolvimento inicial',
      article: 'em',
      illustrationEmoji: '✨',
      lengthText: '-',
      lengthHelper: '-',
      weightText: '-',
      icon: Icons.circle,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFFE66A8C),
      secondaryColor: Color(0xFFB8325A),
      leafColor: Color(0xFF4F8A4C),
    ),
    2: _BabySizeInfo(
      name: 'desenvolvimento inicial',
      article: 'em',
      illustrationEmoji: '✨',
      lengthText: '-',
      lengthHelper: '-',
      weightText: '-',
      icon: Icons.circle,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFFE66A8C),
      secondaryColor: Color(0xFFB8325A),
      leafColor: Color(0xFF4F8A4C),
    ),
    3: _BabySizeInfo(
      name: 'desenvolvimento inicial',
      article: 'em',
      illustrationEmoji: '✨',
      lengthText: '-',
      lengthHelper: '-',
      weightText: '-',
      icon: Icons.circle,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFFE66A8C),
      secondaryColor: Color(0xFFB8325A),
      leafColor: Color(0xFF4F8A4C),
    ),
    4: _BabySizeInfo(
      name: 'semente de papoula',
      article: 'uma',
      illustrationEmoji: '🌱',
      lengthText: '-',
      lengthHelper: '-',
      weightText: '-',
      icon: Icons.grain,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFF6D6D6D),
      secondaryColor: Color(0xFF3E3E3E),
      leafColor: Color(0xFF4F8A4C),
    ),
    5: _BabySizeInfo(
      name: 'semente de gergelim',
      article: 'uma',
      illustrationEmoji: '🌾',
      lengthText: '0.3 cm',
      weightText: '-',
      icon: Icons.grain,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFFE2C08D),
      secondaryColor: Color(0xFFC89A63),
      leafColor: Color(0xFF4F8A4C),
    ),
    6: _BabySizeInfo(
      name: 'semente de roma',
      article: 'uma',
      illustrationEmoji: '🌱',
      lengthText: '0.5 cm',
      weightText: '-',
      icon: Icons.circle,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFFC44343),
      secondaryColor: Color(0xFF8B2F2F),
      leafColor: Color(0xFF4F8A4C),
    ),
    7: _BabySizeInfo(
      name: 'mirtilo',
      article: 'um',
      illustrationEmoji: '🫐',
      lengthText: '1 cm',
      weightText: '1 g',
      icon: Icons.circle,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFF6D86C9),
      secondaryColor: Color(0xFF3F5EA8),
      leafColor: Color(0xFF4F8A4C),
    ),
    8: _BabySizeInfo(
      name: 'framboesa',
      article: 'uma',
      illustrationEmoji: '🍓',
      lengthText: '1.6 cm',
      weightText: '1.3 g',
      icon: Icons.circle,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFFE66A8C),
      secondaryColor: Color(0xFFB8325A),
      leafColor: Color(0xFF4F8A4C),
    ),
    9: _BabySizeInfo(
      name: 'cereja',
      article: 'uma',
      illustrationEmoji: '🍒',
      lengthText: '2.3 cm',
      weightText: '2 g',
      icon: Icons.circle,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFFBD2E4A),
      secondaryColor: Color(0xFF8D1C34),
      leafColor: Color(0xFF4F8A4C),
    ),
    10: _BabySizeInfo(
      name: 'azeitona verde',
      article: 'uma',
      illustrationEmoji: '🫒',
      lengthText: '3.1 cm',
      weightText: '4 g',
      icon: Icons.circle,
      kind: _FruitKind.citrus,
      primaryColor: Color(0xFFC2C96A),
      secondaryColor: Color(0xFF8B9A3E),
      leafColor: Color(0xFF4F8A4C),
    ),
    11: _BabySizeInfo(
      name: 'figo',
      article: 'um',
      illustrationEmoji: '🟣',
      lengthText: '4.1 cm',
      weightText: '8 g',
      icon: Icons.circle,
      kind: _FruitKind.eggplant,
      primaryColor: Color(0xFF8A5FA7),
      secondaryColor: Color(0xFF5B3A99),
      leafColor: Color(0xFF4F8A4C),
    ),
    12: _BabySizeInfo(
      name: 'limao',
      article: 'um',
      illustrationEmoji: '🍋',
      lengthText: '5.4 cm',
      weightText: '14 g',
      icon: Icons.circle_outlined,
      kind: _FruitKind.citrus,
      primaryColor: Color(0xFFFFD94D),
      secondaryColor: Color(0xFFF2C500),
      leafColor: Color(0xFF5FA35C),
    ),
    13: _BabySizeInfo(
      name: 'pessego',
      article: 'um',
      illustrationEmoji: '🍑',
      lengthText: '7.4 cm',
      weightText: '24 g',
      icon: Icons.apple,
      kind: _FruitKind.mango,
      primaryColor: Color(0xFFFFB888),
      secondaryColor: Color(0xFFE87C3D),
      leafColor: Color(0xFF5E9C55),
    ),
    14: _BabySizeInfo(
      name: 'nectarina',
      article: 'uma',
      illustrationEmoji: '🍑',
      lengthText: '8.7 cm',
      weightText: '44 g',
      icon: Icons.apple,
      kind: _FruitKind.mango,
      primaryColor: Color(0xFFFFAB85),
      secondaryColor: Color(0xFFE75F52),
      leafColor: Color(0xFF5E9C55),
    ),
    15: _BabySizeInfo(
      name: 'maca',
      article: 'uma',
      illustrationEmoji: '🍏',
      lengthText: '10.1 cm',
      weightText: '70 g',
      icon: Icons.apple,
      kind: _FruitKind.mango,
      primaryColor: Color(0xFFA7D96C),
      secondaryColor: Color(0xFF6BA73A),
      leafColor: Color(0xFF4F8A4C),
    ),
    16: _BabySizeInfo(
      name: 'abacate',
      article: 'um',
      illustrationEmoji: '🥑',
      lengthText: '11.6 cm',
      weightText: '100 g',
      icon: Icons.spa,
      kind: _FruitKind.avocado,
      primaryColor: Color(0xFF9AC46A),
      secondaryColor: Color(0xFF5F8D40),
      leafColor: Color(0xFF3F6D3D),
    ),
    17: _BabySizeInfo(
      name: 'pera',
      article: 'uma',
      illustrationEmoji: '🍐',
      lengthText: '13 cm',
      weightText: '142 g',
      icon: Icons.energy_savings_leaf,
      kind: _FruitKind.avocado,
      primaryColor: Color(0xFFB9D75B),
      secondaryColor: Color(0xFF7FA034),
      leafColor: Color(0xFF3F6D3D),
    ),
    18: _BabySizeInfo(
      name: 'pimentao',
      article: 'um',
      illustrationEmoji: '🫑',
      lengthText: '14.2 cm',
      weightText: '190 g',
      icon: Icons.emoji_food_beverage,
      kind: _FruitKind.banana,
      primaryColor: Color(0xFFFF8A65),
      secondaryColor: Color(0xFFE05C3E),
      leafColor: Color(0xFF4E8A4B),
    ),
    19: _BabySizeInfo(
      name: 'roma',
      article: 'uma',
      illustrationEmoji: '🔴',
      lengthText: '15.3 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '240 g',
      icon: Icons.circle,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFFC44343),
      secondaryColor: Color(0xFF8B2F2F),
      leafColor: Color(0xFF4F8A4C),
    ),
    20: _BabySizeInfo(
      name: 'espiga de milho',
      article: 'uma',
      illustrationEmoji: '🌽',
      lengthText: '25.6 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '300 g',
      icon: Icons.grass,
      kind: _FruitKind.banana,
      primaryColor: Color(0xFFFFE07A),
      secondaryColor: Color(0xFFE4B83A),
      leafColor: Color(0xFF6E9A50),
    ),
    21: _BabySizeInfo(
      name: 'toranja',
      article: 'uma',
      illustrationEmoji: '🍊',
      lengthText: '26.7 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '360 g',
      icon: Icons.circle_outlined,
      kind: _FruitKind.citrus,
      primaryColor: Color(0xFFFFB36B),
      secondaryColor: Color(0xFFE87C3D),
      leafColor: Color(0xFF5FA35C),
    ),
    22: _BabySizeInfo(
      name: 'abobrinha',
      article: 'uma',
      illustrationEmoji: '🥒',
      lengthText: '27.8 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '430 g',
      icon: Icons.eco,
      kind: _FruitKind.avocado,
      primaryColor: Color(0xFF9AC46A),
      secondaryColor: Color(0xFF5F8D40),
      leafColor: Color(0xFF3F6D3D),
    ),
    23: _BabySizeInfo(
      name: 'manga grande',
      article: 'uma',
      illustrationEmoji: '🥭',
      lengthText: '28.8 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '500 g',
      icon: Icons.apple,
      kind: _FruitKind.mango,
      primaryColor: Color(0xFFFFB347),
      secondaryColor: Color(0xFFE87C3D),
      leafColor: Color(0xFF5E9C55),
    ),
    24: _BabySizeInfo(
      name: 'mamao papaia',
      article: 'um',
      illustrationEmoji: '🍈',
      lengthText: '30 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '600 g',
      icon: Icons.local_florist,
      kind: _FruitKind.papaya,
      primaryColor: Color(0xFFFFB36B),
      secondaryColor: Color(0xFFE36D4E),
      leafColor: Color(0xFF5E9E4F),
    ),
    25: _BabySizeInfo(
      name: 'pomelo',
      article: 'um',
      illustrationEmoji: '🍊',
      lengthText: '34.6 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '670 g',
      icon: Icons.circle_outlined,
      kind: _FruitKind.citrus,
      primaryColor: Color(0xFFFFD94D),
      secondaryColor: Color(0xFFF2C500),
      leafColor: Color(0xFF5FA35C),
    ),
    26: _BabySizeInfo(
      name: 'berinjela',
      article: 'uma',
      illustrationEmoji: '🍆',
      lengthText: '35.6 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '760 g',
      icon: Icons.eco,
      kind: _FruitKind.eggplant,
      primaryColor: Color(0xFF8C66D0),
      secondaryColor: Color(0xFF5B3A99),
      leafColor: Color(0xFF58915B),
    ),
    27: _BabySizeInfo(
      name: 'couve-flor',
      article: 'uma',
      illustrationEmoji: '🥦',
      lengthText: '36.6 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '880 g',
      icon: Icons.spa,
      kind: _FruitKind.avocado,
      primaryColor: Color(0xFFD6E1BA),
      secondaryColor: Color(0xFF8E9A77),
      leafColor: Color(0xFF4E8A4B),
    ),
    28: _BabySizeInfo(
      name: 'abobora japonesa',
      article: 'uma',
      illustrationEmoji: '🎃',
      lengthText: '37.5 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '1.1 kg',
      icon: Icons.circle,
      kind: _FruitKind.papaya,
      primaryColor: Color(0xFFB78A55),
      secondaryColor: Color(0xFF8E6337),
      leafColor: Color(0xFF4E8A4B),
    ),
    29: _BabySizeInfo(
      name: 'abobora cabotia',
      article: 'uma',
      illustrationEmoji: '🎃',
      lengthText: '38.6 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '1.2 kg',
      icon: Icons.circle,
      kind: _FruitKind.papaya,
      primaryColor: Color(0xFFFFB36B),
      secondaryColor: Color(0xFFE36D4E),
      leafColor: Color(0xFF5E9E4F),
    ),
    30: _BabySizeInfo(
      name: 'penca de bananas',
      article: 'uma',
      illustrationEmoji: '🍌',
      lengthText: '39.9 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '1.3 kg',
      icon: Icons.emoji_food_beverage,
      kind: _FruitKind.banana,
      primaryColor: Color(0xFFFFE07A),
      secondaryColor: Color(0xFFE4B83A),
      leafColor: Color(0xFF6E9A50),
    ),
    31: _BabySizeInfo(
      name: 'coco',
      article: 'um',
      illustrationEmoji: '🥥',
      lengthText: '41.1 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '1.5 kg',
      icon: Icons.bubble_chart,
      kind: _FruitKind.coconut,
      primaryColor: Color(0xFFB78A55),
      secondaryColor: Color(0xFF8E6337),
      leafColor: Color(0xFF4E8A4B),
    ),
    32: _BabySizeInfo(
      name: 'cacho de uvas',
      article: 'um',
      illustrationEmoji: '🍇',
      lengthText: '42.4 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '1.7 kg',
      icon: Icons.grain,
      kind: _FruitKind.berry,
      primaryColor: Color(0xFF8EC279),
      secondaryColor: Color(0xFF4A8E4D),
      leafColor: Color(0xFF3F6D3D),
    ),
    33: _BabySizeInfo(
      name: 'abacaxi',
      article: 'um',
      illustrationEmoji: '🍍',
      lengthText: '43.8 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '2 kg',
      icon: Icons.local_florist,
      kind: _FruitKind.papaya,
      primaryColor: Color(0xFFFFD07A),
      secondaryColor: Color(0xFFE6A53A),
      leafColor: Color(0xFF4E8A4B),
    ),
    34: _BabySizeInfo(
      name: 'melao cantalupo',
      article: 'um',
      illustrationEmoji: '🍈',
      lengthText: '45 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '2.2 kg',
      icon: Icons.local_florist,
      kind: _FruitKind.papaya,
      primaryColor: Color(0xFFFFB36B),
      secondaryColor: Color(0xFFE36D4E),
      leafColor: Color(0xFF5E9E4F),
    ),
    35: _BabySizeInfo(
      name: 'melao verde',
      article: 'um',
      illustrationEmoji: '🍈',
      lengthText: '46.3 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '2.4 kg',
      icon: Icons.local_florist,
      kind: _FruitKind.papaya,
      primaryColor: Color(0xFFCFE48D),
      secondaryColor: Color(0xFF8EBE5F),
      leafColor: Color(0xFF5E9E4F),
    ),
    36: _BabySizeInfo(
      name: 'acelga chinesa',
      article: 'uma',
      illustrationEmoji: '🥬',
      lengthText: '47.4 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '2.6 kg',
      icon: Icons.eco,
      kind: _FruitKind.avocado,
      primaryColor: Color(0xFF9AC46A),
      secondaryColor: Color(0xFF5F8D40),
      leafColor: Color(0xFF3F6D3D),
    ),
    37: _BabySizeInfo(
      name: 'coco verde',
      article: 'um',
      illustrationEmoji: '🥥',
      lengthText: '48.5 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '2.9 kg',
      icon: Icons.bubble_chart,
      kind: _FruitKind.coconut,
      primaryColor: Color(0xFFA4CC79),
      secondaryColor: Color(0xFF5D9B55),
      leafColor: Color(0xFF3F6D3D),
    ),
    38: _BabySizeInfo(
      name: 'repolho grande',
      article: 'um',
      illustrationEmoji: '🥬',
      lengthText: '49.8 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '3.1 kg',
      icon: Icons.eco,
      kind: _FruitKind.avocado,
      primaryColor: Color(0xFFA7D96C),
      secondaryColor: Color(0xFF6BA73A),
      leafColor: Color(0xFF3F6D3D),
    ),
    39: _BabySizeInfo(
      name: 'abobora pequena',
      article: 'uma',
      illustrationEmoji: '🎃',
      lengthText: '50.6 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '3.3 kg',
      icon: Icons.circle,
      kind: _FruitKind.papaya,
      primaryColor: Color(0xFFFFB36B),
      secondaryColor: Color(0xFFE36D4E),
      leafColor: Color(0xFF5E9E4F),
    ),
    40: _BabySizeInfo(
      name: 'melancia',
      article: 'uma',
      illustrationEmoji: '🍉',
      lengthText: '51.2 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '3.5 kg',
      icon: Icons.brightness_1,
      kind: _FruitKind.watermelon,
      primaryColor: Color(0xFF6FCF97),
      secondaryColor: Color(0xFF2F9E63),
      leafColor: Color(0xFF4E8A4B),
    ),
    41: _BabySizeInfo(
      name: 'melancia',
      article: 'uma',
      illustrationEmoji: '🍉',
      lengthText: '51.2 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '3.5 kg',
      icon: Icons.brightness_1,
      kind: _FruitKind.watermelon,
      primaryColor: Color(0xFF6FCF97),
      secondaryColor: Color(0xFF2F9E63),
      leafColor: Color(0xFF4E8A4B),
    ),
    42: _BabySizeInfo(
      name: 'melancia',
      article: 'uma',
      illustrationEmoji: '🍉',
      lengthText: '51.2 cm',
      lengthHelper: 'da cabeca aos pes',
      weightText: '3.5 kg',
      icon: Icons.brightness_1,
      kind: _FruitKind.watermelon,
      primaryColor: Color(0xFF6FCF97),
      secondaryColor: Color(0xFF2F9E63),
      leafColor: Color(0xFF4E8A4B),
    ),
  };

  final weekly = weeklyData[currentWeek];
  if (weekly != null) {
    return weekly;
  }

  return const _BabySizeInfo(
    name: 'melancia',
    article: 'uma',
    illustrationEmoji: '🍉',
    lengthText: '51.2 cm',
    lengthHelper: 'da cabeca aos pes',
    weightText: '3.5 kg',
    icon: Icons.brightness_1,
    kind: _FruitKind.watermelon,
    primaryColor: Color(0xFF6FCF97),
    secondaryColor: Color(0xFF2F9E63),
    leafColor: Color(0xFF4E8A4B),
  );
}

String _trimesterForWeek(int currentWeek) {
  if (currentWeek <= 13) return '1o trimestre';
  if (currentWeek <= 27) return '2o trimestre';
  return '3o trimestre';
}

enum _FruitKind {
  berry,
  citrus,
  avocado,
  banana,
  mango,
  eggplant,
  coconut,
  papaya,
  watermelon,
}

class _FruitIllustration extends StatelessWidget {
  const _FruitIllustration({required this.info, required this.week});

  final _BabySizeInfo info;
  final int week;

  @override
  Widget build(BuildContext context) {
    final assetPath = _assetPathForWeek(week);

    if (assetPath != null) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 110,
            height: 110,
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => _buildEmojiFallback(),
            ),
          ),
        ),
      );
    }

    return _buildEmojiFallback();
  }

  String? _assetPathForWeek(int currentWeek) {
    const weekImageMap = <int, String>{
      1: 'src/images/1 semana-Photoroom.png',
      2: 'src/images/2 semanas-Photoroom.png',
      3: 'src/images/3 semanas-Photoroom.png',
      4: 'src/images/4 semanas-Photoroom.png',
      5: 'src/images/5 semanas-Photoroom.png',
      6: 'src/images/6 semanas-Photoroom.png',
      7: 'src/images/7 semanas-Photoroom.png',
      8: 'src/images/8 semanas-Photoroom.png',
      9: 'src/images/9 semanas-Photoroom.png',
      10: 'src/images/10 semanas-Photoroom.png',
      11: 'src/images/11 semanas-Photoroom.png',
      12: 'src/images/12 semanas-Photoroom.png',
      13: 'src/images/13 semanas-Photoroom.png',
      14: 'src/images/14 semanas-Photoroom.png',
      15: 'src/images/15 semanas-Photoroom.png',
      16: 'src/images/16 semanas-Photoroom.png',
      17: 'src/images/17 semanas-Photoroom.png',
      18: 'src/images/18 semanas-Photoroom.png',
      19: 'src/images/19 semanas-Photoroom.png',
      20: 'src/images/20 semanas-Photoroom.png',
      21: 'src/images/21 semanas-Photoroom.png',
      22: 'src/images/22 semanas-Photoroom.png',
      23: 'src/images/23 semanas-Photoroom.png',
      24: 'src/images/24 semanas-Photoroom.png',
      25: 'src/images/25 semanas-Photoroom.png',
      26: 'src/images/26 semanas-Photoroom.png',
      27: 'src/images/27 semanas-Photoroom.png',
      28: 'src/images/28 semanas-Photoroom.png',
      29: 'src/images/29 semanas-Photoroom.png',
      30: 'src/images/30 semanas-Photoroom.png',
      31: 'src/images/31 semanas-Photoroom.png',
      32: 'src/images/32 semanas-Photoroom.png',
      33: 'src/images/33 semanas-Photoroom.png',
      34: 'src/images/34 semanas-Photoroom.png',
      35: 'src/images/35 semanas-Photoroom.png',
      36: 'src/images/36 semanas-Photoroom.png',
      37: 'src/images/37 semanas-Photoroom.png',
      38: 'src/images/38 semanas-Photoroom.png',
      39: 'src/images/39 semanas-Photoroom.png',
      40: 'src/images/40 semanas-Photoroom.png',
      41: 'src/images/41 semanas-Photoroom.png',
      42: 'src/images/42 semanas-Photoroom.png',
    };

    return weekImageMap[currentWeek];
  }

  Widget _buildEmojiFallback() {
    return Center(
      child: Container(
        width: 94,
        height: 94,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.35),
        ),
        alignment: Alignment.center,
        child: Text(
          info.illustrationEmoji ?? _fallbackEmoji(info.kind),
          style: const TextStyle(fontSize: 58),
        ),
      ),
    );
  }

  String _fallbackEmoji(_FruitKind kind) {
    switch (kind) {
      case _FruitKind.berry:
        return '🍓';
      case _FruitKind.citrus:
        return '🍋';
      case _FruitKind.avocado:
        return '🥑';
      case _FruitKind.banana:
        return '🍌';
      case _FruitKind.mango:
        return '🥭';
      case _FruitKind.eggplant:
        return '🍆';
      case _FruitKind.coconut:
        return '🥥';
      case _FruitKind.papaya:
        return '🍈';
      case _FruitKind.watermelon:
        return '🍉';
    }
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: GestCareColors.deepTeal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, textAlign: TextAlign.center),
          if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 18)],
        ],
      ),
    );
  }
}

class _PregnancyWelcomeIllustration extends StatelessWidget {
  const _PregnancyWelcomeIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        color: GestCareColors.cream,
        boxShadow: const [
          BoxShadow(
            color: Color(0x220C7A71),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.asset(
          'src/images/Gemini_Generated_Image_ca70o3ca70o3ca70.png',
          fit: BoxFit.cover,
          semanticLabel: 'Ilustracao de gestante na tela inicial',
        ),
      ),
    );
  }
}
