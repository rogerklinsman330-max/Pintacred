from datetime import datetime, timedelta, timezone, date
from math import pow
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import create_engine, String, Integer, DateTime, Float, ForeignKey, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session
from passlib.context import CryptContext
from jose import jwt, JWTError

DATABASE_URL = "sqlite:///./pintacred_demo.db"
SECRET_KEY = "DEV_ONLY_CHANGE_BEFORE_DEPLOYMENT"
ALGORITHM = "HS256"

class Base(DeclarativeBase): pass
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})

class User(Base):
    __tablename__="users"; id:Mapped[int]=mapped_column(primary_key=True); name:Mapped[str]=mapped_column(String(120)); email:Mapped[str]=mapped_column(String(200),unique=True,index=True); phone:Mapped[str]=mapped_column(String(30)); password_hash:Mapped[str]=mapped_column(String(255)); created_at:Mapped[datetime]=mapped_column(DateTime,default=lambda:datetime.now(timezone.utc))
class Simulation(Base):
    __tablename__="simulations"; id:Mapped[int]=mapped_column(primary_key=True); user_id:Mapped[int]=mapped_column(ForeignKey("users.id"),index=True); principal:Mapped[float]=mapped_column(Float); term:Mapped[int]=mapped_column(Integer); monthly_rate:Mapped[float]=mapped_column(Float); installment:Mapped[float]=mapped_column(Float); total:Mapped[float]=mapped_column(Float); created_at:Mapped[datetime]=mapped_column(DateTime,default=lambda:datetime.now(timezone.utc))
class Application(Base):
    __tablename__="applications"; id:Mapped[int]=mapped_column(primary_key=True); user_id:Mapped[int]=mapped_column(ForeignKey("users.id"),index=True); simulation_id:Mapped[int]=mapped_column(ForeignKey("simulations.id")); status:Mapped[str]=mapped_column(String(30)); rule_version:Mapped[str]=mapped_column(String(30),default="demo-v1"); decision_reason:Mapped[str]=mapped_column(String(255)); created_at:Mapped[datetime]=mapped_column(DateTime,default=lambda:datetime.now(timezone.utc))
class Offer(Base):
    __tablename__="offers"; id:Mapped[int]=mapped_column(primary_key=True); application_id:Mapped[int]=mapped_column(ForeignKey("applications.id"),unique=True); principal:Mapped[float]=mapped_column(Float); term:Mapped[int]=mapped_column(Integer); monthly_rate:Mapped[float]=mapped_column(Float); cet_demo:Mapped[float]=mapped_column(Float); installment:Mapped[float]=mapped_column(Float); total:Mapped[float]=mapped_column(Float); status:Mapped[str]=mapped_column(String(30),default="AVAILABLE"); created_at:Mapped[datetime]=mapped_column(DateTime,default=lambda:datetime.now(timezone.utc))
class ContractDemo(Base):
    __tablename__="contracts_demo"; id:Mapped[int]=mapped_column(primary_key=True); user_id:Mapped[int]=mapped_column(ForeignKey("users.id"),index=True); offer_id:Mapped[int]=mapped_column(ForeignKey("offers.id"),unique=True); status:Mapped[str]=mapped_column(String(30),default="ACTIVE_DEMO"); accepted_at:Mapped[datetime]=mapped_column(DateTime,default=lambda:datetime.now(timezone.utc))
class InstallmentDemo(Base):
    __tablename__="installments_demo"; id:Mapped[int]=mapped_column(primary_key=True); contract_id:Mapped[int]=mapped_column(ForeignKey("contracts_demo.id"),index=True); number:Mapped[int]=mapped_column(Integer); due_date:Mapped[str]=mapped_column(String(10)); amount:Mapped[float]=mapped_column(Float); status:Mapped[str]=mapped_column(String(20),default="OPEN")

Base.metadata.create_all(engine)
pwd=CryptContext(schemes=["bcrypt"],deprecated="auto"); oauth2=OAuth2PasswordBearer(tokenUrl="auth/login")
app=FastAPI(title="Pintacred Demo API",version="0.3.0"); app.add_middleware(CORSMiddleware,allow_origins=["*"],allow_credentials=True,allow_methods=["*"],allow_headers=["*"])

class RegisterIn(BaseModel): name:str; email:EmailStr; phone:str; password:str
class UserOut(BaseModel): id:int; name:str; email:str; phone:str
class SimulationIn(BaseModel): principal:float=Field(ge=100,le=500); term:int
class SimulationOut(BaseModel): id:int; principal:float; term:int; monthly_rate:float; installment:float; total:float; demo:bool=True
class ApplicationIn(BaseModel): simulation_id:int
class ApplicationOut(BaseModel): id:int; status:str; decision_reason:str; offer_id:int|None=None; demo:bool=True
class OfferOut(BaseModel): id:int; principal:float; term:int; monthly_rate:float; cet_demo:float; installment:float; total:float; status:str; demo:bool=True
class InstallmentOut(BaseModel): number:int; due_date:str; amount:float; status:str
class ContractOut(BaseModel): id:int; status:str; principal:float; term:int; installment:float; total:float; installments:list[InstallmentOut]; demo:bool=True

@app.get('/health')
def health(): return {'status':'ok','mode':'demo','version':'0.3.0'}
@app.post('/auth/register',response_model=UserOut)
def register(data:RegisterIn):
    with Session(engine) as db:
        if db.scalar(select(User).where(User.email==data.email.lower())): raise HTTPException(409,'E-mail já cadastrado')
        if len(data.password)<8: raise HTTPException(400,'A senha deve ter ao menos 8 caracteres')
        u=User(name=data.name.strip(),email=data.email.lower(),phone=data.phone.strip(),password_hash=pwd.hash(data.password)); db.add(u);db.commit();db.refresh(u);return UserOut(id=u.id,name=u.name,email=u.email,phone=u.phone)
@app.post('/auth/login')
def login(form:OAuth2PasswordRequestForm=Depends()):
    with Session(engine) as db:
        u=db.scalar(select(User).where(User.email==form.username.lower()))
        if not u or not pwd.verify(form.password,u.password_hash): raise HTTPException(401,'Credenciais inválidas')
        return {'access_token':jwt.encode({'sub':str(u.id),'exp':datetime.now(timezone.utc)+timedelta(hours=8)},SECRET_KEY,algorithm=ALGORITHM),'token_type':'bearer'}
def current_user(token:str=Depends(oauth2)):
    try: uid=int(jwt.decode(token,SECRET_KEY,algorithms=[ALGORITHM])['sub'])
    except (JWTError,KeyError,ValueError): raise HTTPException(401,'Token inválido')
    with Session(engine) as db:
        u=db.get(User,uid)
        if not u: raise HTTPException(401,'Usuário não encontrado')
        return UserOut(id=u.id,name=u.name,email=u.email,phone=u.phone)
@app.get('/me',response_model=UserOut)
def me(user:UserOut=Depends(current_user)): return user
@app.post('/simulations',response_model=SimulationOut)
def create_simulation(data:SimulationIn,user:UserOut=Depends(current_user)):
    if data.term not in (3,6,9,12): raise HTTPException(400,'Prazo deve ser 3, 6, 9 ou 12 parcelas')
    rate=.029; inst=round(data.principal*rate/(1-pow(1+rate,-data.term)),2); total=round(inst*data.term,2)
    with Session(engine) as db:
        s=Simulation(user_id=user.id,principal=data.principal,term=data.term,monthly_rate=rate,installment=inst,total=total);db.add(s);db.commit();db.refresh(s);return SimulationOut(id=s.id,principal=s.principal,term=s.term,monthly_rate=s.monthly_rate,installment=s.installment,total=s.total)
@app.post('/applications',response_model=ApplicationOut)
def apply(data:ApplicationIn,user:UserOut=Depends(current_user)):
    with Session(engine) as db:
        s=db.get(Simulation,data.simulation_id)
        if not s or s.user_id!=user.id: raise HTTPException(404,'Simulação não encontrada')
        # Motor DEMO v1: determinístico e transparente, sem dados reais.
        if s.principal<=300: status,reason='PRE_APPROVED','Faixa de teste até R$ 300: pré-aprovação demonstrativa.'
        elif s.term<=6: status,reason='UNDER_REVIEW','Valor acima de R$ 300: encaminhado para análise demonstrativa.'
        else: status,reason='NOT_ELIGIBLE','Combinação valor/prazo fora da política demonstrativa v1.'
        a=Application(user_id=user.id,simulation_id=s.id,status=status,decision_reason=reason);db.add(a);db.flush(); offer_id=None
        if status=='PRE_APPROVED':
            o=Offer(application_id=a.id,principal=s.principal,term=s.term,monthly_rate=s.monthly_rate,cet_demo=s.monthly_rate,installment=s.installment,total=s.total);db.add(o);db.flush();offer_id=o.id
        db.commit();db.refresh(a);return ApplicationOut(id=a.id,status=a.status,decision_reason=a.decision_reason,offer_id=offer_id)
@app.get('/offers/{offer_id}',response_model=OfferOut)
def get_offer(offer_id:int,user:UserOut=Depends(current_user)):
    with Session(engine) as db:
        o=db.get(Offer,offer_id)
        if not o: raise HTTPException(404,'Proposta não encontrada')
        a=db.get(Application,o.application_id)
        if not a or a.user_id!=user.id: raise HTTPException(403,'Acesso negado')
        return OfferOut(id=o.id,principal=o.principal,term=o.term,monthly_rate=o.monthly_rate,cet_demo=o.cet_demo,installment=o.installment,total=o.total,status=o.status)
@app.post('/offers/{offer_id}/accept',response_model=ContractOut)
def accept_offer(offer_id:int,user:UserOut=Depends(current_user)):
    with Session(engine) as db:
        o=db.get(Offer,offer_id)
        if not o: raise HTTPException(404,'Proposta não encontrada')
        a=db.get(Application,o.application_id)
        if not a or a.user_id!=user.id: raise HTTPException(403,'Acesso negado')
        existing=db.scalar(select(ContractDemo).where(ContractDemo.offer_id==offer_id))
        if existing: c=existing
        else:
            c=ContractDemo(user_id=user.id,offer_id=o.id);db.add(c);db.flush();o.status='ACCEPTED';a.status='ACCEPTED'
            today=date.today()
            for n in range(1,o.term+1):
                # Datas demo: intervalos de 30 dias para simplificar o protótipo.
                due=today+timedelta(days=30*n);db.add(InstallmentDemo(contract_id=c.id,number=n,due_date=due.isoformat(),amount=o.installment))
            db.commit();db.refresh(c)
        rows=db.scalars(select(InstallmentDemo).where(InstallmentDemo.contract_id==c.id).order_by(InstallmentDemo.number)).all()
        return ContractOut(id=c.id,status=c.status,principal=o.principal,term=o.term,installment=o.installment,total=o.total,installments=[InstallmentOut(number=x.number,due_date=x.due_date,amount=x.amount,status=x.status) for x in rows])
@app.get('/contracts',response_model=list[ContractOut])
def contracts(user:UserOut=Depends(current_user)):
    with Session(engine) as db:
        cs=db.scalars(select(ContractDemo).where(ContractDemo.user_id==user.id).order_by(ContractDemo.id.desc())).all(); out=[]
        for c in cs:
            o=db.get(Offer,c.offer_id); rows=db.scalars(select(InstallmentDemo).where(InstallmentDemo.contract_id==c.id).order_by(InstallmentDemo.number)).all();out.append(ContractOut(id=c.id,status=c.status,principal=o.principal,term=o.term,installment=o.installment,total=o.total,installments=[InstallmentOut(number=x.number,due_date=x.due_date,amount=x.amount,status=x.status) for x in rows]))
        return out
