import 'package:flutter/material.dart';
import 'package:rx_notifier/rx_notifier.dart';

import 'package:app/common/base/base_state.dart';
import 'package:app/feature/example/controller/example_controller.dart';

/// The View. A `StatefulWidget` whose private `State` extends
/// `BaseState<ExamplePage, ExampleController>`. The base injects the Controller,
/// runs its lifecycle, and wires the global message/redirect observers — so
/// this file only describes UI and reads Controller state inside `RxBuilder`.
class ExamplePage extends StatefulWidget {
  final String itemId;

  const ExamplePage({super.key, required this.itemId});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends BaseState<ExamplePage, ExampleController> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState(); // BaseState calls controller.onInit() + wires observers
    controller.loadItems(); // controller is injected by the base
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 200) {
      controller.loadMore();
    }
  }

  @override
  void dispose() {
    // Dispose only View-local controllers here. Do NOT dispose `controller` —
    // BaseState.dispose() already does (guarded by disposeController).
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Example')),
      // Wrap the smallest subtree that depends on a given piece of state. Reads
      // inside the builder are tracked automatically; reads outside it are
      // one-shot and will NOT rebuild.
      body: RxBuilder(
        builder: (context) {
          if (controller.isLoading == true) {
            return const Center(child: CircularProgressIndicator());
          }
          final List items = controller.items; // reactive read -> this builder reacts
          return ListView.builder(
            controller: _scrollController,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.title),
                onTap: () => controller.selected = item, // direct mutation, no dispatch
              );
            },
          );
        },
      ),
    );
  }
}
