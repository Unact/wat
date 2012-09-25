concept interface;


define 'procedure', 'interface.debt';
define 'procedure', 'interface.debt_accept';
define 'procedure', 'interface.proce';
define 'service', 'xml';

if not exists (select * from systable where table_name='agent' and user_name(creator)='interface') then

 create table interface.agent(

    id int default autoincrement, username varchar(128) not null,
    foreign key ( palm_salesman ) references dbo.palm_salesman on delete set null,

    created datetime default now(), ts timestamp default timestamp, 
    primary key (id)
 );

end if;

if not exists (select * from interface.agent where username='sasha') then
  insert into interface.agent (username, palm_salesman) values ('sasha',965);
  commit
end if;

if not exists (select * from interface.agent where username='g.vyazova') then
--  insert into interface.agent (username, palm_salesman) values ('g.vyazova',802);
  commit
end if;

if not exists (select * from systable where table_name='request' and user_name(creator)='interface') then

 create table interface.request(

    id uniqueidentifier default newid(), type varchar(32) default 'get', request xml, response xml,

    created datetime default now(), ts timestamp default timestamp, 
    primary key (id)
 );

 create trigger interface.ti_request before insert on interface.request
  referencing new as inserted
  for each row
 begin
   return;
 end

end if;

alter trigger interface.ti_request before insert on interface.request
  referencing new as inserted
  for each row
begin
declare @result xml;
declare @sql text;
declare @view varchar(128);


savepoint;

 body: begin

  select name, 
         string('set @result=', name, '.', inserted.type,'(',if data is null then 'null' else ''''+data+'''' endif,')')
    into @view, @sql
    from openxml (inserted.request,'/*') with (name varchar(128) '@mp:localname', data xml '*:data/@mp:xmltext')
  ;

  execute immediate @sql;

  exception when others then
     set @result=
          xmlelement('exception',
                       xmlelement('ErrorText',errormsg())
                      ,xmlelement('SQLSTATE',SQLSTATE)
                      ,xmlelement('SQL', @sql)
                      ,xmlelement('Request', inserted.request)
          );
    rollback to savepoint;
 end;



set inserted.response=
    xmlelement (@view,
      xmlattributes ('http://unact.ru/xmlns/xmlinterface' as "xmlns",
                     'http://unact.ru/xmlns/xmlinterface' as "xmlns:xi"
      ),
      @result
)

end;



alter procedure interface.proce (in @type varchar(10) default 'get', in @data xml default null)
begin
 call dbo.sa_set_http_header( 'Content-Type', 'text/xml' );
 call sa_set_http_option ( 'CharsetConversion', 'off');

 case @type
  when 'get' then
   select interface.debt ();
  when 'put' then
   select interface.debt_accept (@data)
  else
   select xmlelement('exception',
                     xmlconcat(xmlelement('ErrorText','Use /get or /put')
                              
                     )
          );
 end case;
end;

alter service xml
type 'raw'
authorization off user dba
url elements
as call interface.proce(:url1, :data)
;



alter function interface.debt_accept (in @data xml)
returns xml
begin
 declare @result xml;
 declare @intid varchar(128);

 savepoint;

 body: begin
   declare @res int;
   declare @xml xml;
   declare @pays int;

   for debt as debt cursor for 
       select *
         from openxml(@data, '//*:data//*:debt[@modified]')
              with (debt_id int '@id', cash varchar(32) '@cash',
                    ndoc varchar(64) '@ndoc', doc_id int '@doc_id',
                    cdesk int '../../@srv_cashdesk', cash_id int '@cash_id',
                    @status1 int '@status1', @intid_local varchar(128) '@intId')
   do
     set @intid=@intid_local;
     set cash_id=nullif(cash_id,0);

     case
       when cash_id is null and cash>0 then
         set cash_id=idgenerator('cassa_income')
         ;
         insert into cassa_income with auto name
           select cash_id id, $partner.anyCashclient(partner) client,
                  cash summ, 0 currency,
                  string('Оплата товара накл. ',ndoc,' от ', date(payspt.ddate)) info,
                  1 "number", cdesk, 0 pay_type, today() as ddate, payspt.org as org,
                  nullif(@status1,0) as status1
             from payspt 
            where payspt.id=debt_id
         ;
       when cash_id is not null and cash>0 then
         delete ptplink where pay_id=(select pays from cassa_income where id=cash_id)
         ;
         update cassa_income set summ=cash, status1=isnull(@status1,0)
          where id=cash_id
         ;
       when cash_id is not null and isnull(cash,0)=0 then
         delete cassa_income
          where id=cash_id
         ;
         set @result=xmlconcat(@result,xmlelement ('deleted', xmlattributes (@intid as intId, '' as cash_id)))
         ;
     end case
     ;
 

     set @result=xmlconcat(@result,(select @intId as intId, cash_id from cassa_income modified where id=cash_id for xml auto))
     ;

     select paidpt.id into @xml 
       from paidpt join recgoods on pays=paidpt.id and recgoods.id=doc_id for xml auto
     ;

     select pays into @pays from cassa_income where id=cash_id;

     set @res=$ptpays.link(@pays,xmlelement('debts',@xml));

     if exists (select * from ptpaid join cassa_income ci on ci.pays=ptpaid.id where ci.id=cash_id) then
       set @result=
          xmlelement('exception',xmlattributes (@intid as "intId"),
                     xmlconcat(xmlelement('ErrorText',string('Задолженность по накладной № ', ndoc, ' меньше полученной суммы ', cash))
                     )
          )
       ;
       rollback to savepoint;
       leave body;
     end if;

   end for;

   set @result=xmlelement ('accepted',@result);

 exception
   when others then
     set @result=
          xmlelement('exception',xmlattributes (@intid as "intId"),
                     xmlconcat(xmlelement('ErrorText',errormsg())
                              ,xmlelement('SQLSTATE',SQLSTATE)
                     )
          );
     rollback to savepoint;
 end;

return  xmlelement ('response',
                    xmlattributes ('http://unact.ru/database' as "xmlns",
                                   'http://www.w3.org/2001/XMLSchema' as "xmlns:xs"
                    ),
                    @result
)
end;


alter function interface.debt (in @request xml)
returns xml
begin
declare @result xml;

body: begin
 declare @meta xml;
 declare @cdesk int;
 declare @ddate smalldatetime;
 declare @pgroup int;
 declare @salesman integer;
 declare @agent_username varchar(128);

 set @agent_username=_xml.PathContent(@request,'/*/@username/text()');

 if @agent_username is null then
     set @result=
          xmlelement('exception',xmlattributes ('http://unact.ru/database' as "xmlns"),
                     xmlconcat(xmlelement('ErrorText','Agent not specified')
                     )
          );
     leave body
 end if;

 select palm_salesman into @salesman from interface.agent where username=@agent_username;

 if @salesman is null then
     set @result=
          xmlelement('exception',xmlattributes ('http://unact.ru/database' as "xmlns"),
                     xmlconcat(xmlelement('ErrorText','Для работы интерфейса требуется произвести настройку - не задан торговый представитель для пользователя '+@agent_username)
                     )
          );
     leave body
 end if;


 select srv_cashdesk, today() , srv_pgroup, salesman_id
   into @cdesk,@ddate, @pgroup, @salesman
   from palm_salesman 
  where salesman_id=@salesman 
 ;

 set @meta='
 <xs:schema>
 <xs:element name="salesman">
  <xs:complexType>
   <xs:all>
    <xs:element name="buyer">
     <xs:complexType>
      <xs:all>
       <xs:element name="debt">
        <xs:complexType>
          <!-- xs:attribute name="id" type="xs:integer" /-->
          <xs:attribute name="ndoc" type="xs:string" caption="Накладная №"/>
          <xs:attribute name="ddate" type="xs:date" caption="Дата" />
          <xs:attribute name="summ" type="xs:decimal" class="number" caption="Задолженность" />
          <xs:attribute name="cash" type="xs:decimal" class="number" caption="Оплачено" editable="true" />
          <xs:attribute name="status1" type="xs:boolean" class="boolean" caption="Чек" editable="true" />
        </xs:complexType >
       </xs:element>
      </xs:all>
      <xs:attribute name="name" type="xs:string" />
      <xs:attribute name="address" type="xs:string" />
     </xs:complexType>
    </xs:element>
   </xs:all>
   <xs:attribute name="name" type="xs:string" />
  </xs:complexType>
 </xs:element>
 </xs:schema>
 ';

 set temporary option for_xml_null_treatment='empty';

 with
 debt as
 (select recept.ndoc, date(recept.ddate) ddate, recept.client,
         isnull(cast(sum(summ) as decimal(18,2)),0)+isnull(cash,0) summ, min(predebt.id) id,
         predebt.doc_id, cast(sum(cash) as decimal(18,2)) cash, min(cash_id) cash_id, min(status1) status1
 from recept join 
  (select paidpt.csum as summ, paidpt.id,
                recgoods.id doc_id, null cash, null cash_id, null status1
     from recgoods
          join paidpt on paidpt.id=recgoods.pays
          join partners on partners.id=paidpt.partner
    where partners.parent=@pgroup
  union all
    select null, null,
                 min(recgoods.id), ci.summ, ci.id, ci.status1
      from cassa_income ci
        join ptplink on ptplink.pay_id=ci.pays 
        join recgoods  on ptplink.upay_id=recgoods.pays
    where ci.ddate=today() and ci.cdesk=@cdesk
     group by  ci.id, ci.summ, ci.status1
    having count(distinct recgoods.id) = 1
   ) as predebt on predebt.doc_id=recept.id
 group by recept.ndoc, recept.ddate, recept.client, predebt.doc_id
 )
  select 
             salesman.name, salesman.srv_cashdesk,
             buyer.name, buyer.loadto address, buyer.id, buyer.partner,
             debt.ndoc, debt.ddate, debt.summ, debt.id,
             debt.cash, debt.cash_id, debt.doc_id, debt.status1
   into @result
   from debt 
             join buyers buyer  on buyer.id=debt.client
             cross join palm_salesman salesman 
  where salesman.salesman_id=@salesman 
  order by 1,2,3,4,5 desc
  for xml auto
 ;

 set @result=xmlconcat(
     xmlelement ('metadata',@meta),
     xmlelement ('data',@result)
 );

exception when others then
     set @result=
          xmlelement('exception',
                     xmlconcat(xmlelement('ErrorText',errormsg())
                              ,xmlelement('SQLSTATE',SQLSTATE)
                     )
          );
end;

return  xmlelement ('response',
                    xmlattributes ('http://unact.ru/database' as "xmlns",
                                   'http://www.w3.org/2001/XMLSchema' as "xmlns:xs",
                                   'http://unact.ru/database' as "xmlns:db"
                    ),
                    @result
)

end;
