import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

import '../../../models/transaction_model.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardInitialFechEvent>(dashboardInitialFechEvent);
    on<DashboardDepositEvent>(dashboardDepositEvent);
    on<DashboardWithdrawEvent>(dashboardWithdrawEvent);
  }

  String publicKey = "0xBbDa377bd36651523C4D31c487f42Af08E65e2d0";

  List<TransactionModel> transactions = [];
  Web3Client? _web3client;
  late ContractAbi _abiCode;
  late EthereumAddress _contractAddress;
  late EthPrivateKey _creds;
  int balance = 0;

  // Functions
  late DeployedContract _deployedContract;
  late ContractFunction _deposit;
  late ContractFunction _withdraw;
  late ContractFunction _getBalance;
  late ContractFunction _getAllTransactions;

  Future<FutureOr<void>> dashboardInitialFechEvent(
      DashboardInitialFechEvent event, Emitter<DashboardState> emit) async {
    emit(DashboardLoadingState());

    try {
      const String rpcUrl = "http://10.0.2.2:7545";
      const String socketUrl = "ws://10.0.2.2:7545";
      const String privateKey =
          "0x07071b7a5a92c72c690685e4941e23a3dc55d05cc68f2e0ad792ce3778808eb8";

      _web3client = Web3Client(
        rpcUrl,
        http.Client(),
        socketConnector: () {
          return IOWebSocketChannel.connect(socketUrl).cast<String>();
        },
      );

      // getABI
      String abiFile =
          await rootBundle.loadString('build/contracts/ExpenseContract.json');
      var jsonDecoded = jsonDecode(abiFile);
      _abiCode = ContractAbi.fromJson(
          jsonEncode(jsonDecoded['abi']), 'ExpenseContract');
      _contractAddress =
          EthereumAddress.fromHex(jsonDecoded["networks"]["5777"]["address"]);

      _creds = EthPrivateKey.fromHex(privateKey);

      //get deployed contract
      _deployedContract = DeployedContract(_abiCode, _contractAddress);
      _deposit = _deployedContract.function("deposit");
      _withdraw = _deployedContract.function("withdraw");
      _getBalance = _deployedContract.function("getBalance");
      _getAllTransactions = _deployedContract.function("getAllTransaction");

      final transactionsData = await _web3client!.call(
          contract: _deployedContract,
          function: _getAllTransactions,
          params: []);
      log("transactionsData --> ${transactionsData.toString()}");

      final balanceData = await _web3client!
          .call(contract: _deployedContract, function: _getBalance, params: [
        EthereumAddress.fromHex(publicKey),
      ]);
      log("balanceData --> ${balanceData.toString()}");
      List<TransactionModel> trans = [];
      for (int i = 0; i < transactionsData[0].length; i++) {
        TransactionModel transactionModel = TransactionModel(
          transactionsData[0][i].toString(),
          transactionsData[1][i].toInt(),
          transactionsData[2][i],
          DateTime.fromMicrosecondsSinceEpoch(transactionsData[3][i].toInt()),
          transactionType: transactionsData[4][i].toInt(),
        );
        trans.add(transactionModel);
      }
      transactions = trans;

      int bal = balanceData[0].toInt();
      balance = bal;
      emit(DashboardSuccessState(transactions: transactions, balance: balance));
    } catch (e) {
      log("e --> ${e.toString()}");
      emit(DashboardErrorState());
    }
  }

  FutureOr<void> dashboardDepositEvent(
      DashboardDepositEvent event, Emitter<DashboardState> emit) async {
    try {
      final transaction = Transaction.callContract(
        from: EthereumAddress.fromHex(publicKey),
        contract: _deployedContract,
        function: _deposit,
        parameters: [
          BigInt.from(event.transactionModel.amount),
          event.transactionModel.reason
        ],
        value: EtherAmount.inWei(
          BigInt.from(event.transactionModel.amount),
        ),
      );

      final result = _web3client!.sendTransaction(
        _creds,
        transaction,
        chainId: 1337,
        fetchChainIdFromNetworkId: false,
      );
      log("deposit result --> ${result.toString()}");
      Future.delayed(const Duration(milliseconds: 500), () {
        add(DashboardInitialFechEvent());
      });
    } catch (e) {
      log("dashboardDepositEvent e --> ${e.toString()}");
    }
  }

  FutureOr<void> dashboardWithdrawEvent(
      DashboardWithdrawEvent event, Emitter<DashboardState> emit) async {
    try {
      final transaction = Transaction.callContract(
        from: EthereumAddress.fromHex(publicKey),
        contract: _deployedContract,
        function: _withdraw,
        parameters: [
          BigInt.from(event.transactionModel.amount),
          event.transactionModel.reason
        ],
      );

      final result = _web3client!.sendTransaction(
        _creds,
        transaction,
        chainId: 1337,
        fetchChainIdFromNetworkId: false,
      );
      log("withdraw result --> ${result.toString()}");
      Future.delayed(const Duration(milliseconds: 500), () {
        add(DashboardInitialFechEvent());
      });
    } catch (e) {
      log("dashboardWithdrawEvent e --> ${e.toString()}");
    }
  }
}
