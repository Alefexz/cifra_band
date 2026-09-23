import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/account_deletion_service.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key, this.loadOptions, this.submit});
  final Future<Map<String, dynamic>> Function()? loadOptions;
  final Future<void> Function(String password, Map<String, String> successors)?
  submit;
  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _password = TextEditingController();
  final _successors = <String, String>{};
  List<dynamic>? _ministries;
  bool _confirmed = false;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result =
          await (widget.loadOptions?.call() ??
              AccountDeletionService.call('options', {}));
      if (mounted) {
        setState(() {
          _ministries = result['ministries'] as List;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Nao foi possivel carregar. Tente novamente.');
      }
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.submit ?? AccountDeletionService.request)(
        _password.text,
        _successors,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Nao foi possivel confirmar. Confira sua senha, os sucessores e a conexao.',
        );
      }
    } finally {
      _password.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Excluir conta')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Esta acao e permanente',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Seu perfil, tickets, notas, downloads e setlists pessoais serao apagados. '
          'Suas contribuicoes identificadas em dados compartilhados tambem serao removidas. '
          'O trabalho dos demais integrantes sera preservado. O processamento pode continuar apos voce sair.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Um protocolo e um bloqueio tecnico da conta serao mantidos por 30 dias. '
          'Dados de telemetria ja enviados seguem a retencao dos provedores. '
          'Outros aparelhos offline nao podem ser apagados remotamente.',
        ),
        if (_ministries == null && _error == null)
          const LinearProgressIndicator(),
        for (final ministry in _ministries ?? [])
          if ((ministry['members'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Novo administrador: ${ministry['name']}',
                ),
                items: [
                  for (final member in ministry['members'])
                    DropdownMenuItem(
                      value: member['uid'] as String,
                      child: Text(
                        '${member['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) =>
                          setState(() => _successors[ministry['id']] = value!),
              ),
            ),
        const SizedBox(height: 24),
        TextField(
          controller: _password,
          obscureText: true,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'Senha atual'),
          onChanged: (_) => setState(() {}),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _confirmed,
          title: const Text('Entendo que a exclusao e permanente.'),
          onChanged: _busy
              ? null
              : (value) => setState(() => _confirmed = value ?? false),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        if (_ministries == null && _error != null)
          TextButton(onPressed: _load, child: const Text('Tentar novamente')),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed:
              !_busy &&
                  _confirmed &&
                  _password.text.isNotEmpty &&
                  _ministries != null &&
                  _ministries!.every(
                    (m) =>
                        (m['members'] as List).isEmpty ||
                        _successors.containsKey(m['id']),
                  )
              ? _submit
              : null,
          icon: const Icon(Icons.delete_forever),
          label: Text(_busy ? 'Confirmando...' : 'Excluir minha conta'),
        ),
      ],
    ),
  );
}

class AccountDeletionProgressScreen extends StatefulWidget {
  const AccountDeletionProgressScreen({super.key});
  @override
  State<AccountDeletionProgressScreen> createState() =>
      _AccountDeletionProgressScreenState();
}

class _AccountDeletionProgressScreenState
    extends State<AccountDeletionProgressScreen> {
  String _message = 'Verificando o protocolo...';
  bool _busy = false;
  bool _notFound = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notFound = false;
    });
    try {
      final data = await AccountDeletionService.call('status', {
        'receipt': AccountDeletionService.pending.value!['receipt'],
      }, authenticated: false);
      await AccountDeletionService.clearLocal();
      if (mounted) {
        setState(
          () => _message = data['status'] == 'complete'
              ? 'Conta excluida e dados locais apagados.'
              : 'Solicitacao aceita. Dados locais apagados. A limpeza no servidor continua e sera retomada se houver interrupcao.',
        );
      }
    } on AccountDeletionException catch (error) {
      if (mounted) {
        setState(() {
          _notFound = error.status == 404;
          _message = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Nao foi possivel concluir a verificacao ou a limpeza local. Tente novamente. Seu protocolo foi guardado.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Exclusao de conta'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.privacy_tip_outlined, size: 48),
          const SizedBox(height: 24),
          Text(_message),
          const SizedBox(height: 24),
          const Text('Protocolo'),
          SelectableText(
            '${AccountDeletionService.pending.value?['receipt'] ?? ''}',
          ),
          TextButton.icon(
            onPressed: () => Clipboard.setData(
              ClipboardData(
                text: '${AccountDeletionService.pending.value?['receipt']}',
              ),
            ),
            icon: const Icon(Icons.copy),
            label: const Text('Copiar protocolo'),
          ),
          const SelectableText(AccountDeletionService.pageUrl),
          const SizedBox(height: 24),
          if (_busy) const LinearProgressIndicator(),
          FilledButton(
            onPressed: _busy ? null : _check,
            child: const Text('Consultar andamento'),
          ),
          if (_notFound)
            TextButton(
              onPressed: AccountDeletionService.cancelUnaccepted,
              child: const Text('Voltar: solicitacao nao recebida'),
            ),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Fechar aplicativo'),
          ),
        ],
      ),
    ),
  );
}
