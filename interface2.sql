grant connect to interface;

define 'procedure', 'interface.debt';
define 'procedure', 'interface.proce';
define 'service', 'xml';


alter procedure interface.proce ()
begin
 call dbo.sa_set_http_header( 'Content-Type', 'text/xml' );
 call sa_set_http_option ( 'CharsetConversion', 'off');
 select interface.debt ('',133)
end;

alter service xml
type 'raw'
authorization off user dba
url elements
as call interface.proce()
;


alter function interface.debt
    (in @login varchar(128) default current user,
     in @salesman integer default null, in @date date default today())
returns xml
begin
declare @result xml;
declare @meta xml;
declare @stylesheet varchar(256);

set @meta='
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
<xs:element name="salesman">
 <xs:complexType>
  <xs:all>
   <xs:element name="buyer">
    <xs:complexType>
     <xs:all>
      <xs:element name="debt">
       <xs:complexType>
         <xs:attribute name="id" type="xs:integer" />
         <xs:attribute name="info" type="xs:string" />
         <xs:attribute name="summ" type="xs:decimal" />
         <xs:attribute name="ddate" type="xs:date" />
         <xs:attribute name="cash" type="xs:decimal" editable="true" />
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

set @meta=@meta+isnull(posted_data(),'');


set @stylesheet=if not (coalesce(http_variable('nostyle'),http_variable('url1'),'') in ('nostyle','1','yes'))
                 then '<?xml-stylesheet type="text/xsl" href="/'+current database+'/interface.xsl"?> '
                 else ''
                endif
;

with debt as
  (select paidpt.csum as summ, payspt.id, payspt.partner, date(payspt.ddate) ddate, payspt.info, recept.client
     from recept key join recgoods key join payspt key join paidpt
  )
  select 
             salesman.name,
             buyer.name, buyer.loadto address,
             debt.info, debt.ddate, sum(debt.summ) as summ, min(debt.id) as id
  into @result
   from debt join partners on partners.id=debt.partner
             join palm_salesman salesman on partners.parent=salesman.srv_pgroup
             join buyers buyer  on buyer.id=debt.client
   where salesman.salesman_id=133
   group by salesman.name,
                   buyer.name, buyer.loadto,
                   debt.info, debt.ddate
  order by 1,2,3,4,5 desc
  for xml auto, elements
;

return '<?xml version="1.0" encoding="windows-1251" ?> '+
-- @stylesheet+ 
 xmlelement ('form',
     xmlelement ('metadata',@meta),
     xmlelement ('data',@result)
 );
end;
