import 'package:flutter/material.dart';

import '../api.dart';
import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showGangChatSheet(
  BuildContext context,
  GameController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _GangChatSheet(controller: controller),
  );
}

class _GangChatSheet extends StatefulWidget {
  const _GangChatSheet({required this.controller});

  final GameController controller;

  @override
  State<_GangChatSheet> createState() => _GangChatSheetState();
}

class _GangChatSheetState extends State<_GangChatSheet> {
  final _text = TextEditingController();
  GangChatInfo? _chat;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chat = await widget.controller.api.gangChat();
      if (mounted) setState(() => _chat = chat);
    } on ApiException {
      if (mounted) setState(() => _chat = null);
    }
  }

  Future<void> _run(Future<GangChatInfo> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final chat = await action();
      if (mounted) setState(() => _chat = chat);
      await widget.controller.refresh();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    await _run(() => widget.controller.api.sendGangChat(text));
    _text.clear();
  }

  Future<void> _payout(int amount) =>
      _run(() => widget.controller.api.payoutTreasury(amount));

  Future<void> _promote(String id) =>
      _run(() => widget.controller.api.promoteGangMember(id));

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final leader = chat?.myRole == 'leader';
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: GH.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: GH.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GH.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('BĂNG',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1)),
                  const SizedBox(width: 8),
                  if (chat != null)
                    Text(
                      'quỹ ${formatMoney(chat.treasury)}đ · ${chat.members.length} người',
                      style: labelStyle(size: 10.5),
                    ),
                  const Spacer(),
                  if (leader && (chat?.treasury ?? 0) > 0)
                    SizedBox(
                      width: 108,
                      child: PrimaryButton(
                        label: 'CHIA QUỸ',
                        icon: Icons.payments_rounded,
                        height: 32,
                        color: GH.gold,
                        enabled: !_busy,
                        onTap: () => _payout(chat!.treasury),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (chat != null)
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final m in chat.members)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: leader && m.role != 'leader'
                                ? () => _promote(m.id)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: GH.panel2,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: GH.line),
                              ),
                              child: Text(
                                '${m.name}${m.role == 'leader' ? ' ★' : m.role == 'officer' ? ' ▲' : ''}',
                                style: labelStyle(
                                  size: 10,
                                  color: m.role == 'member' ? GH.muted : GH.gold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: chat == null
                    ? const Center(
                        child: CircularProgressIndicator(color: GH.pink))
                    : chat.messages.isEmpty
                        ? Center(
                            child: Text('Chưa ai nói gì. Khai mào đi.',
                                style: labelStyle(size: 12)),
                          )
                        : ListView.builder(
                            reverse: true,
                            itemCount: chat.messages.length,
                            itemBuilder: (context, i) {
                              final m = chat.messages[chat.messages.length - 1 - i];
                              final mine = m.name ==
                                  widget.controller.state?.name;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? GH.cyan.withValues(alpha: 0.14)
                                        : GH.panel2,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: mine
                                          ? GH.cyan.withValues(alpha: 0.4)
                                          : GH.line,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: mine
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${m.name}${m.role == 'leader' ? ' · băng trưởng' : m.role == 'officer' ? ' · phó băng' : ''}',
                                        style: labelStyle(
                                            size: 9,
                                            color: mine ? GH.cyan : GH.muted),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(m.text,
                                          style: const TextStyle(fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      style: const TextStyle(fontSize: 13),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Nói gì đó với anh em...',
                        hintStyle: labelStyle(size: 12),
                        filled: true,
                        fillColor: GH.panel2,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: GH.line),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: PrimaryButton(
                      label: 'GỬI',
                      height: 40,
                      enabled: !_busy,
                      onTap: _send,
                    ),
                  ),
                ],
              ),
              if (chat != null && chat.log.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  chat.log.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle(size: 9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
