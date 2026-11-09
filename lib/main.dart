import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8000');
const demoNotice = 'DEMONSTRAÇÃO — não use dados reais ou dinheiro real';

void main() => runApp(const PintacredApp());

class Api {
  static Future<String?> token() async => (await SharedPreferences.getInstance()).getString('token');
  static Future<void> saveToken(String value) async { await (await SharedPreferences.getInstance()).setString('token', value); }
  static Future<void> logout() async { await (await SharedPreferences.getInstance()).remove('token'); }
  static Future<Map<String, String>> headers() async => {
    'Content-Type': 'application/json',
    if (await token() case final String t) 'Authorization': 'Bearer $t',
  };
  static dynamic decode(http.Response response) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 300) {
      throw Exception(data is Map ? (data['detail'] ?? 'Erro ${response.statusCode}') : 'Erro ${response.statusCode}');
    }
    return data;
  }
  static Future<void> register(String name, String email, String phone, String password) async {
    decode(await http.post(Uri.parse('$apiBase/auth/register'), headers: {'Content-Type':'application/json'},
      body: jsonEncode({'name':name, 'email':email, 'phone':phone, 'password':password})));
  }
  static Future<void> login(String email, String password) async {
    final data = decode(await http.post(Uri.parse('$apiBase/auth/login'),
      headers: {'Content-Type':'application/x-www-form-urlencoded'},
      body: {'username':email,'password':password}));
    await saveToken(data['access_token'] as String);
  }
  static Future<Map<String,dynamic>> me() async => Map<String,dynamic>.from(
    decode(await http.get(Uri.parse('$apiBase/me'), headers:await headers())));
  static Future<Map<String,dynamic>> simulate(double amount, int term) async => Map<String,dynamic>.from(
    decode(await http.post(Uri.parse('$apiBase/simulations'), headers:await headers(),
      body:jsonEncode({'principal':amount,'term':term}))));
  static Future<Map<String,dynamic>> apply(int id) async => Map<String,dynamic>.from(
    decode(await http.post(Uri.parse('$apiBase/applications'), headers:await headers(),
      body:jsonEncode({'simulation_id':id}))));
  static Future<Map<String,dynamic>> offer(int id) async => Map<String,dynamic>.from(
    decode(await http.get(Uri.parse('$apiBase/offers/$id'), headers:await headers())));
  static Future<Map<String,dynamic>> accept(int id) async => Map<String,dynamic>.from(
    decode(await http.post(Uri.parse('$apiBase/offers/$id/accept'), headers:await headers())));
  static Future<List<dynamic>> contracts() async => List<dynamic>.from(
    decode(await http.get(Uri.parse('$apiBase/contracts'), headers:await headers())));
}

String money(num value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
String errorText(Object error) => error.toString().replaceFirst('Exception: ', '');
void showError(BuildContext context, Object error) => ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content:Text(errorText(error))));

class PintacredApp extends StatelessWidget {
  const PintacredApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title:'Pintacred', debugShowCheckedModeBanner:false,
    theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF00A859)),useMaterial3:true),
    home:const WelcomePage());
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width:double.infinity, padding:const EdgeInsets.all(12), color:const Color(0xFFFFF0B8),
    child:const Text(demoNotice,textAlign:TextAlign.center));
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body:SafeArea(child:Column(children:[
    const DemoBanner(),
    Expanded(child:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(
      mainAxisSize:MainAxisSize.min,children:[
        const Text('Pintacred',style:TextStyle(fontSize:42,fontWeight:FontWeight.bold,color:Color(0xFF0B2D5C))),
        const SizedBox(height:8), const Text('Crédito simples quando você precisa.'),
        const SizedBox(height:32),
        FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RegisterPage())),child:const Text('Criar conta demo')),
        OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const LoginPage())),child:const Text('Entrar')),
      ]))))
  ])));
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override State<RegisterPage> createState()=>_RegisterPageState();
}
class _RegisterPageState extends State<RegisterPage> {
  final form=GlobalKey<FormState>();
  final name=TextEditingController(), email=TextEditingController(), phone=TextEditingController(), password=TextEditingController();
  bool busy=false;
  @override void dispose(){name.dispose();email.dispose();phone.dispose();password.dispose();super.dispose();}
  Future<void> submit() async {
    if(!form.currentState!.validate())return;
    setState(()=>busy=true);
    try {
      await Api.register(name.text,email.text,phone.text,password.text);
      if(!mounted)return;
      Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>LoginPage(initialEmail:email.text)));
    } catch(e){if(mounted)showError(context,e);} finally {if(mounted)setState(()=>busy=false);}
  }
  Widget field(TextEditingController c,String label,{bool secret=false}) => Padding(
    padding:const EdgeInsets.only(bottom:12),child:TextFormField(controller:c,obscureText:secret,
      decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
      validator:(v)=>(v==null||v.trim().isEmpty)?'Preencha este campo':null));
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Criar conta demo')),
    body:Form(key:form,child:ListView(padding:const EdgeInsets.all(20),children:[
      const DemoBanner(),const SizedBox(height:20),field(name,'Nome fictício'),field(email,'E-mail fictício'),
      field(phone,'Telefone fictício'),field(password,'Senha de teste',secret:true),
      FilledButton(onPressed:busy?null:submit,child:Text(busy?'Aguarde...':'Continuar')),
    ])));
}

class LoginPage extends StatefulWidget {
  final String initialEmail;
  const LoginPage({super.key,this.initialEmail=''});
  @override State<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  late final email=TextEditingController(text:widget.initialEmail);
  final password=TextEditingController();bool busy=false;
  @override void dispose(){email.dispose();password.dispose();super.dispose();}
  Future<void> submit()async{
    setState(()=>busy=true);
    try{await Api.login(email.text,password.text);if(!mounted)return;
      Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const HomePage()),(_)=>false);
    }catch(e){if(mounted)showError(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Entrar')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const DemoBanner(),const SizedBox(height:20),
      TextField(controller:email,decoration:const InputDecoration(labelText:'E-mail fictício',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Senha',border:OutlineInputBorder())),
      const SizedBox(height:20),FilledButton(onPressed:busy?null:submit,child:Text(busy?'Entrando...':'Entrar')),
    ]));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage> {
  String name='';
  @override void initState(){super.initState();Api.me().then((v){if(mounted)setState(()=>name=v['name'].toString());}).catchError((Object e){if(mounted)showError(context,e);});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Pintacred'),actions:[
    IconButton(icon:const Icon(Icons.logout),onPressed:()async{await Api.logout();if(!context.mounted)return;
      Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const WelcomePage()),(_)=>false);})]),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const DemoBanner(),const SizedBox(height:24),Text('Olá, $name!',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      const SizedBox(height:24),FilledButton.icon(icon:const Icon(Icons.calculate),label:const Text('Simular empréstimo'),
        onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SimulatorPage()))),
      const SizedBox(height:12),OutlinedButton.icon(icon:const Icon(Icons.receipt_long),label:const Text('Meus empréstimos demo'),
        onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ContractsPage()))),
    ]));
}

class SimulatorPage extends StatefulWidget {
  const SimulatorPage({super.key});
  @override State<SimulatorPage> createState()=>_SimulatorPageState();
}
class _SimulatorPageState extends State<SimulatorPage> {
  double amount=250;int term=6;bool busy=false;Map<String,dynamic>? result;
  Future<void> simulate()async{
    setState(()=>busy=true);
    try{final r=await Api.simulate(amount,term);if(mounted)setState(()=>result=r);}
    catch(e){if(mounted)showError(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Simulador demo')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const DemoBanner(),const SizedBox(height:20),const Text('Quanto você precisa?',style:TextStyle(fontSize:22)),
      Center(child:Text(money(amount),style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold))),
      Slider(value:amount,min:100,max:500,divisions:8,label:money(amount),onChanged:(v)=>setState((){amount=v;result=null;})),
      const Text('Número de parcelas'),
      DropdownButton<int>(value:term,isExpanded:true,items:[3,6,9,12].map((n)=>DropdownMenuItem(value:n,child:Text('$n parcelas'))).toList(),
        onChanged:(v)=>setState((){term=v??6;result=null;})),
      FilledButton(onPressed:busy?null:simulate,child:Text(busy?'Calculando...':'Calcular')),
      if(result!=null)...[
        const SizedBox(height:24),Text('Parcela: ${money((result!['installment'] as num))}'),
        Text('Total: ${money((result!['total'] as num))}'),
        const Text('Taxas fictícias, sem validade comercial.'),
        const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(
          builder:(_)=>DecisionPage(simulationId:result!['id'] as int))),child:const Text('Solicitar análise demo')),
      ]
    ]));
}

class DecisionPage extends StatefulWidget {
  final int simulationId;
  const DecisionPage({super.key,required this.simulationId});
  @override State<DecisionPage> createState()=>_DecisionPageState();
}
class _DecisionPageState extends State<DecisionPage> {
  Map<String,dynamic>? result;String? error;
  @override void initState(){super.initState();Api.apply(widget.simulationId).then((v){if(mounted)setState(()=>result=v);})
    .catchError((Object e){if(mounted)setState(()=>error=errorText(e));});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Análise demo')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const DemoBanner(),const SizedBox(height:24),
      if(result==null&&error==null)const Center(child:CircularProgressIndicator()),
      if(error!=null)Text(error!),
      if(result!=null)...[
        Text('Resultado: ${result!['status']}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
        const SizedBox(height:10),Text('${result!['decision_reason']}'),
        if(result!['offer_id']!=null)...[
          const SizedBox(height:20),FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(
            builder:(_)=>OfferPage(offerId:result!['offer_id'] as int))),child:const Text('Ver proposta demo')),
        ]
      ]
    ]));
}

class OfferPage extends StatefulWidget {
  final int offerId;
  const OfferPage({super.key,required this.offerId});
  @override State<OfferPage> createState()=>_OfferPageState();
}
class _OfferPageState extends State<OfferPage> {
  Map<String,dynamic>? offer;String? error;bool busy=false;
  @override void initState(){super.initState();Api.offer(widget.offerId).then((v){if(mounted)setState(()=>offer=v);})
    .catchError((Object e){if(mounted)setState(()=>error=errorText(e));});}
  Future<void> accept()async{
    setState(()=>busy=true);
    try{final contract=await Api.accept(widget.offerId);if(!mounted)return;
      Navigator.push(context,MaterialPageRoute(builder:(_)=>ContractPage(contract:contract)));
    }catch(e){if(mounted)showError(context,e);}finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Proposta demo')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const DemoBanner(),const SizedBox(height:20),
      if(offer==null&&error==null)const Center(child:CircularProgressIndicator()),
      if(error!=null)Text(error!),
      if(offer!=null)...[
        Text('Valor: ${money(offer!['principal'] as num)}'),
        Text('Parcelas: ${offer!['term']} x ${money(offer!['installment'] as num)}'),
        Text('Total: ${money(offer!['total'] as num)}'),
        Text('Juros mensais demonstrativos: ${offer!['monthly_rate']}'),
        Text('CET demonstrativo: ${offer!['cet_demo']}'),
        const SizedBox(height:16),const Text('Aceite fictício. Não há contrato ou transferência real.'),
        const SizedBox(height:16),FilledButton(onPressed:busy?null:accept,child:Text(busy?'Aguarde...':'Aceitar proposta demo')),
      ]
    ]));
}

class ContractPage extends StatelessWidget {
  final Map<String,dynamic> contract;
  const ContractPage({super.key,required this.contract});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Contrato demo')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const DemoBanner(),const SizedBox(height:20),
      Text('Contrato #${contract['id']} — ${contract['status']}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
      Text('Total: ${money(contract['total'] as num)}'),
      const SizedBox(height:20),const Text('Parcelas fictícias:'),
      for(final item in (contract['installments'] as List<dynamic>))
        ListTile(title:Text('Parcela ${item['number']}: ${money(item['amount'] as num)}'),
          subtitle:Text('Vencimento: ${item['due_date']} — ${item['status']}')),
    ]));
}

class ContractsPage extends StatefulWidget {
  const ContractsPage({super.key});
  @override State<ContractsPage> createState()=>_ContractsPageState();
}
class _ContractsPageState extends State<ContractsPage> {
  List<dynamic>? contracts;String? error;
  @override void initState(){super.initState();Api.contracts().then((v){if(mounted)setState(()=>contracts=v);})
    .catchError((Object e){if(mounted)setState(()=>error=errorText(e));});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Meus empréstimos demo')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const DemoBanner(),const SizedBox(height:20),
      if(contracts==null&&error==null)const Center(child:CircularProgressIndicator()),
      if(error!=null)Text(error!),
      if(contracts!=null&&contracts!.isEmpty)const Text('Nenhum empréstimo demonstrativo.'),
      for(final item in contracts??<dynamic>[])
        Card(child:ListTile(title:Text('Contrato #${item['id']} — ${money(item['principal'] as num)}'),
          subtitle:Text('${item['status']}'),trailing:const Icon(Icons.chevron_right),
          onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ContractPage(contract:Map<String,dynamic>.from(item)))))),
    ]));
}
