import 'package:algo_wallet_kms/algo_wallet_kms.dart';
import 'package:algorand_dart/algorand_dart.dart';
import 'package:convert/convert.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late AccountConfig _accountConfig;
  late SecureWallet _secureWallet;
  late Account _account;

  @override
  void initState() {
    _secureWallet = SecureWallet(
      walletConfig:
          SecureWalletConfig(storageKeyPrivateKeyPrefix: 'wallet_private_keys'),
    );
    Account.random().then((account) {
      _account = account;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            MaterialButton(
              color: Colors.amber,
              onPressed: () async {
                _accountConfig = await _secureWallet.addAccount(
                  account: _account,
                  biometricAccessControl: BiometricAccessControl.biometryNone,
                );
                _printAccount(_accountConfig, _account);
              },
              child: Text("Create with biometryNone"),
            ),
            MaterialButton(
              color: Colors.amber,
              onPressed: () async {
                _accountConfig = await _secureWallet.addAccount(
                  account: _account,
                  biometricAccessControl: BiometricAccessControl.biometryAny,
                );
                _printAccount(_accountConfig, _account);
              },
              child: Text("Create with biometryAny"),
            ),
            MaterialButton(
              color: Colors.amber,
              onPressed: () async {
                _accountConfig = await _secureWallet.addAccount(
                  account: _account,
                  biometricAccessControl:
                      BiometricAccessControl.biometryCurrentSet,
                );
                _printAccount(_accountConfig, _account);
              },
              child: Text("Create with biometryCurrentSet"),
            ),
            MaterialButton(
              color: Colors.amber,
              onPressed: () async {
                _accountConfig =
                    await _secureWallet.updateAccountBiometricAccessControl(
                  accountConfig: _accountConfig,
                  biometricAccessControl: BiometricAccessControl.biometryNone,
                  encryptionKey: null,
                );
                _printAccount(_accountConfig, null);
              },
              child: Text("Set biometryNone"),
            ),
            MaterialButton(
              color: Colors.amber,
              onPressed: () async {
                _accountConfig =
                    await _secureWallet.updateAccountBiometricAccessControl(
                  accountConfig: _accountConfig,
                  biometricAccessControl: BiometricAccessControl.biometryAny,
                  encryptionKey: null,
                );
                _printAccount(_accountConfig, null);
              },
              child: Text("Set biometryAny"),
            ),
            MaterialButton(
              color: Colors.amber,
              onPressed: () async {
                _accountConfig =
                    await _secureWallet.updateAccountBiometricAccessControl(
                  accountConfig: _accountConfig,
                  biometricAccessControl:
                      BiometricAccessControl.biometryCurrentSet,
                  encryptionKey: null,
                );
                _printAccount(_accountConfig, null);
              },
              child: Text("Set biometryCurrentSet"),
            ),
            MaterialButton(
              color: Colors.amber,
              onPressed: () async {
                List<String> words = await _secureWallet.exportAccount(
                  accountConfig: _accountConfig,
                );
                Account account = await Account.fromSeedPhrase(words);
                _printAccount(_accountConfig, account);
              },
              child: Text("Read"),
            ),
            MaterialButton(
              color: Colors.amber,
              onPressed: () async {
                await _secureWallet.removeAccount(_accountConfig);
              },
              child: Text("Delete"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printAccount(
      AccountConfig accountConfig, Account? account) async {
    print('Account address: ${accountConfig.publicAddress}');
    print(
        'Account biometric protection: ${accountConfig.biometricAccessControl}');
    final keyPair = await account?.keyPair.extract();
    String privateKey =
        hex.encode(await keyPair?.extractPrivateKeyBytes() ?? []);
    print('Private key (hex): $privateKey');
  }
}
