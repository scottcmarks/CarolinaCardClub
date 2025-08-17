import 'package:flutter/material.dart';

class Page1 extends StatelessWidget {
  const Page1({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          child: const Text('Go to Page 2'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Page2())),
        ),
        ElevatedButton(
          child: const Text('Go to Page 3'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Page3())),
        ),
      ],
    );
  }
}

class Page2 extends StatelessWidget {
  const Page2({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        child: const Text('Go to Page 3'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Page3())),
      ),
    );
  }
}

class Page3 extends StatelessWidget {
  const Page3({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Page 3'),
    );
  }
}
