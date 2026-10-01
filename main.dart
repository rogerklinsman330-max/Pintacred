import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8000');

void main() => runApp(const PintacredApp());

class Api {
  static Future<String?> token() async => (await SharedPreferences.getInstance()).getString('token');
  static Future<void> saveToken(String t) async => (await SharedPreferences.getInstance()).setString('token', t);
  static Future<void> logout() async => (await SharedPreferences.getInstance()).remove('token');
  static Map<String,String> jsonHeaders([String? t]) => {'Content-Type':'application/json', if(t!=null) 'Authorization':'Bearer $t'};

  static Future<void> register(String name, String email, String phone, String password) async {
    final r=await http.post(Uri.parse('$apiBase/auth/register'), headers: jsonHeaders(), body: jsonEncode({'name':name,'email':email,'phone':phone,'password':password}));
    if(r.statusCode>=300) throw Exception(_detail(r));
  }
  static Future<void> login(String email, String password) async {
    final r=await http.post(Uri.parse('$apiBase/auth/login'), headers:{'Content-Type':'application/x-www-form-urlencoded'}, body:{'username':email,'password':password});
    if(r.statusCode>=300) throw Exception(_detail(r));
    await saveToken(jsonDecode(r.body)['access_token']);
  }
  static Future<Map<String,dynamic>> me() async {
    final t=await token(); final r=await http.get(Uri.parse('$apiBase/me'), headers:jsonHeaders(t));
    if(r.statusCode>=300) throw Exception(_detail(r)); return jsonDecode(r.body);
  }
  static Future<Map<String,dynamic>> simulate(double principal, int term) async {
    final t=await token(); final r=await http.post(Uri.parse('$apiBase/simulations'), headers:jsonHeaders(t), body:jsonEncode({'principal':principal,'term':term}));
    if(r.statusCode>=300) throw Exception(_detail(r)); return jsonDecode(r.body);
  }
  static Future<Map<String,dynamic>> apply(int simulationId) async { final t=await token(); final r=await http.post(Uri.parse('$apiBase/applications'),headers:jsonHeaders(t),body:jsonEncode({'simulation_id':simulationId})); if(r.statusCode>=300) throw Exception(_detail(r)); return jsonDecode(r.body); }
  static Future<Map<String,dynamic>> offer(int id) async { final t=await token(); final r=await http.get(Uri.parse('$apiBase/offers/$id'),headers:jsonHeaders(t)); if(r.statusCode>=300) throw Exception(_detail(r)); return jsonDecode(r.body); }
  static Future<Map<String,dynamic>> acceptOffer(int id) async { final t=await token(); final r=await http.post(Uri.parse('$apiBase/offers/$id/accept'),headers:jsonHeaders(t)); if(r.statusCode>=300) throw Exception(_detail(r)); return jsonDecode(r.body); }
  static Future<List<dynamic>> contracts() async { final t=await token(); final r=await http.get(Uri.parse('$apiBase/contracts'),headers:jsonHeaders(t)); if(r.statusCode>=300) throw Exception(_detail(r)); return jsonDecode(r.body); }
  static String _detail(http.Response r){ try { return jsonDecode(r.body)['detail'].toString(); } catch(_){ return 'Erro ${r.statusCode}'; } }
}

class PintacredApp extends StatelessWidget {
  const PintacredApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'Pintacred',
    theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF00A859)),useMaterial3:true,scaffoldBackgroundColor:const Color(0xFFF8FAFC)),
    home:const WelcomePage());
}

class DemoBanner extends StatelessWidget { const DemoBanner({super.key}); @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(9),color:const Color(0xFFFFF4CC),child:const Text('DEMONSTRAÇÃO • NÃO USE DADOS REAIS',textAlign:TextAlign.center,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700))); }

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Column(children:[const DemoBanner(),Expanded(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    const Spacer(),const Text('Pintacred',style:TextStyle(fontSize:42,fontWeight:FontWeight.w800,color:Color(0xFF0B2D5C))),const SizedBox(height:8),const Text('Crédito simples quando você precisa.',textAlign:TextAlign.center,style:TextStyle(fontSize:18)),const SizedBox(height:48),
    SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RegisterPage())),child:const Padding(padding:EdgeInsets.all(15),child:Text('Criar minha conta')))),const SizedBox(height:12),
    SizedBox(width:double.infinity,child:OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const LoginPage())),child:const Padding(padding:EdgeInsets.all(15),child:Text('Já tenho conta')))),const Spacer(),
  ])))])));
}

class RegisterPage extends StatefulWidget { const RegisterPage({super.key}); @override State<RegisterPage> createState()=>_RegisterPageState(); }
class _RegisterPageState extends State<RegisterPage>{
  final form=GlobalKey<FormState>(); final name=TextEditingController(),email=TextEditingController(),phone=TextEditingController(),pass=TextEditingController(); bool busy=false;
  Future<void> submit() async { if(!form.currentState!.validate()) return; setState(()=>busy=true); try { await Api.register(name.text,email.text,phone.text,pass.text); if(!mounted)return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Conta demo criada. Agora faça login.'))); Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>LoginPage(initialEmail:email.text))); } catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ','')))); } finally { if(mounted)setState(()=>busy=false); } }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Crie sua conta')),body:Form(key:form,child:ListView(padding:const EdgeInsets.all(24),children:[const Text('Use somente informações fictícias.',style:TextStyle(fontWeight:FontWeight.w600)),const SizedBox(height:20),field(name,'Nome fictício'),field(email,'E-mail fictício',emailType:true),field(phone,'Celular fictício'),field(pass,'Senha de teste',secret:true),FilledButton(onPressed:busy?null:submit,child:Padding(padding:const EdgeInsets.all(15),child:Text(busy?'Criando...':'Continuar')))]));
  Widget field(TextEditingController c,String label,{bool secret=false,bool emailType=false})=>Padding(padding:const EdgeInsets.only(bottom:14),child:TextFormField(controller:c,obscureText:secret,keyboardType:emailType?TextInputType.emailAddress:null,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),validator:(v){if(v==null||v.trim().isEmpty)return 'Preencha este campo';if(secret&&v.length<8)return 'Use ao menos 8 caracteres';return null;}));
}

class LoginPage extends StatefulWidget { final String initialEmail; const LoginPage({super.key,this.initialEmail=''}); @override State<LoginPage> createState()=>_LoginPageState(); }
class _LoginPageState extends State<LoginPage>{ late final email=TextEditingController(text:widget.initialEmail); final pass=TextEditingController(); bool busy=false;
  Future<void> submit() async {setState(()=>busy=true);try{await Api.login(email.text,pass.text);if(!mounted)return;Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const HomePage()),(_)=>false);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{if(mounted)setState(()=>busy=false);}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Entrar')),body:ListView(padding:const EdgeInsets.all(24),children:[TextField(controller:email,decoration:const InputDecoration(labelText:'E-mail fictício',border:OutlineInputBorder())),const SizedBox(height:14),TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Senha de teste',border:OutlineInputBorder())),const SizedBox(height:18),FilledButton(onPressed:busy?null:submit,child:Padding(padding:const EdgeInsets.all(15),child:Text(busy?'Entrando...':'Entrar')))]));
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage>{ Map<String,dynamic>? user; @override void initState(){super.initState();Api.me().then((v){if(mounted)setState(()=>user=v);});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Pintacred'),actions:[IconButton(onPressed:()async{await Api.logout();if(!context.mounted)return;Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const WelcomePage()),(_)=>false);},icon:const Icon(Icons.logout))]),body:ListView(padding:const EdgeInsets.all(24),children:[const DemoBanner(),const SizedBox(height:24),Text('Olá, ${user?['name']??'cliente demo'}!',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w800,color:Color(0xFF0B2D5C))),const SizedBox(height:8),const Text('Faça uma simulação sem compromisso. Nenhum dinheiro real é movimentado nesta versão.'),const SizedBox(height:28),Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.payments_outlined,size:34),const SizedBox(height:12),const Text('Precisa de quanto?',style:TextStyle(fontSize:20,fontWeight:FontWeight.w700)),const Text('Simule de R$ 100 a R$ 500.'),const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SimulatorPage())),child:const Text('Simular empréstimo'))),const SizedBox(height:10),SizedBox(width:double.infinity,child:OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ContractsPage())),child:const Text('Meus empréstimos demo')))])))]));
}

class SimulatorPage extends StatefulWidget { const SimulatorPage({super.key}); @override State<SimulatorPage> createState()=>_SimulatorPageState(); }
class _SimulatorPageState extends State<SimulatorPage>{ double value=250; int term=6; bool busy=false; Map<String,dynamic>? result;
  Future<void> run() async{setState(()=>busy=true);try{final r=await Api.simulate(value,term);if(mounted)setState(()=>result=r);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}finally{if(mounted)setState(()=>busy=false);}}
  String money(num n)=>'R\$ ${n.toStringAsFixed(2).replaceAll('.',',')}';
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Simular empréstimo')),body:ListView(padding:const EdgeInsets.all(24),children:[const Text('Quanto você precisa?',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),const SizedBox(height:8),Center(child:Text(money(value),style:const TextStyle(fontSize:34,fontWeight:FontWeight.w800,color:Color(0xFF00A859)))),Slider(value:value,min:100,max:500,divisions:8,label:money(value),onChanged:(v)=>setState((){value=v;result=null;})),const SizedBox(height:18),const Text('Em quantas parcelas?',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:8),Wrap(spacing:8,children:[3,6,9,12].map((n)=>ChoiceChip(label:Text('${n}x'),selected:term==n,onSelected:(_)=>setState((){term=n;result=null;}))).toList()),const SizedBox(height:22),FilledButton(onPressed:busy?null:run,child:Padding(padding:const EdgeInsets.all(15),child:Text(busy?'Calculando...':'Calcular simulação'))),if(result!=null)...[const SizedBox(height:24),Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Resultado demonstrativo',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:12),Text('Valor: ${money(result!['principal'])}'),Text('Prazo: ${result!['term']} parcelas'),Text('Parcela: ${money(result!['installment'])}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w700)),Text('Total: ${money(result!['total'])}'),Text('Taxa demo: ${(result!['monthly_rate']*100).toStringAsFixed(2).replaceAll('.',',')}% a.m.'),const SizedBox(height:12),const Text('Taxa exclusivamente de teste; não representa oferta comercial.',style:TextStyle(fontSize:12,fontStyle:FontStyle.italic)),const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>DecisionPage(simulationId:result!['id']))),child:const Text('Solicitar análise demo')))]))]]));
}


class DecisionPage extends StatefulWidget { final int simulationId; const DecisionPage({super.key,required this.simulationId}); @override State<DecisionPage> createState()=>_DecisionPageState(); }
class _DecisionPageState extends State<DecisionPage>{ Map<String,dynamic>? data; bool busy=true; @override void initState(){super.initState();Api.apply(widget.simulationId).then((v){if(mounted)setState((){data=v;busy=false;});}).catchError((e){if(mounted){setState(()=>busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}});}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Análise demonstrativa')),body:Padding(padding:const EdgeInsets.all(24),child:busy?const Center(child:CircularProgressIndicator()):Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const DemoBanner(),const SizedBox(height:24),Icon(data?['status']=='PRE_APPROVED'?Icons.check_circle:data?['status']=='UNDER_REVIEW'?Icons.schedule:Icons.info,size:70,color:data?['status']=='PRE_APPROVED'?const Color(0xFF00A859):null),const SizedBox(height:18),Text(data?['status']=='PRE_APPROVED'?'Pré-aprovado no modo demo':data?['status']=='UNDER_REVIEW'?'Em análise demonstrativa':'Não elegível nesta regra demo',textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),const SizedBox(height:12),Text(data?['decision_reason']??'',textAlign:TextAlign.center),const Spacer(),if(data?['offer_id']!=null)FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>OfferPage(offerId:data!['offer_id']))),child:const Padding(padding:EdgeInsets.all(15),child:Text('Ver proposta demo')))])));
}
class OfferPage extends StatefulWidget{final int offerId;const OfferPage({super.key,required this.offerId});@override State<OfferPage> createState()=>_OfferPageState();}
class _OfferPageState extends State<OfferPage>{Map<String,dynamic>? o;bool busy=true;String money(num n)=>'R\$ ${n.toStringAsFixed(2).replaceAll('.',',')}';@override void initState(){super.initState();Api.offer(widget.offerId).then((v){if(mounted)setState((){o=v;busy=false;});});} Future<void> accept()async{setState(()=>busy=true);final c=await Api.acceptOffer(widget.offerId);if(!mounted)return;Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>ContractPage(contract:c)));}
@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Proposta demonstrativa')),body:busy?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(24),children:[const DemoBanner(),const SizedBox(height:20),const Text('Sua proposta demo',style:TextStyle(fontSize:26,fontWeight:FontWeight.w800)),const SizedBox(height:18),Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Valor: ${money(o!['principal'])}'),Text('Prazo: ${o!['term']}x'),Text('Parcela: ${money(o!['installment'])}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w700)),Text('Total: ${money(o!['total'])}'),Text('Taxa demo: ${(o!['monthly_rate']*100).toStringAsFixed(2)}% a.m.'),const SizedBox(height:10),const Text('CET exibido aqui é apenas um campo demonstrativo. Não constitui oferta real.',style:TextStyle(fontSize:12,fontStyle:FontStyle.italic))]))),const SizedBox(height:18),FilledButton(onPressed:accept,child:const Padding(padding:EdgeInsets.all(15),child:Text('Aceitar proposta demo')))]));}
}
class ContractPage extends StatelessWidget{final Map<String,dynamic> contract;const ContractPage({super.key,required this.contract});String money(num n)=>'R\$ ${n.toStringAsFixed(2).replaceAll('.',',')}';@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Empréstimo demo')),body:ListView(padding:const EdgeInsets.all(24),children:[const DemoBanner(),const SizedBox(height:18),const Icon(Icons.verified,size:64,color:Color(0xFF00A859)),const Text('Proposta aceita!',textAlign:TextAlign.center,style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)),const Text('Nenhum valor real foi liberado.',textAlign:TextAlign.center),const SizedBox(height:24),...((contract['installments']??[]) as List).map((x)=>Card(child:ListTile(title:Text('Parcela ${x['number']} • ${money(x['amount'])}'),subtitle:Text('Vencimento demo: ${x['due_date']}'),trailing:Text(x['status']))))]));}
class ContractsPage extends StatefulWidget{const ContractsPage({super.key});@override State<ContractsPage> createState()=>_ContractsPageState();}
class _ContractsPageState extends State<ContractsPage>{List<dynamic>? items;@override void initState(){super.initState();Api.contracts().then((v){if(mounted)setState(()=>items=v);});}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Meus empréstimos demo')),body:items==null?const Center(child:CircularProgressIndicator()):items!.isEmpty?const Center(child:Text('Nenhum contrato demonstrativo ainda.')):ListView(padding:const EdgeInsets.all(16),children:items!.map((c)=>Card(child:ListTile(title:Text('Contrato demo #${c['id']} • ${c['term']}x'),subtitle:Text('Status: ${c['status']}'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ContractPage(contract:c)))))).toList()));}
