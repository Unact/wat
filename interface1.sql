grant connect to interface;

define 'procedure', 'interface.debt';
-- create index palm_salesman_srv_pgroup on palm_salesman (srv_pgroup);
-- interface.debt  @salesman=133
alter procedure interface.debt
    (in @login varchar(128) default current user,
     in @salesman integer default null, in @date date default today())
begin
 select distinct 1 as tag, null as parent,
      palm_salesman.name as [salesman!1!name], 
      null as [buyer!2!name], null as [buyer!2!address], 
      null as [debt!3!info], null as [debt!3!date], null as [debt!3!ammount]
   from paidpt key join payspt join partners on partners.id=paidpt.partner
     key join buyers join palm_salesman on partners.parent=palm_salesman.srv_pgroup
 where (@salesman is null or palm_salesman.salesman_id=@salesman)
 union all
 select distinct  2, 1,
      palm_salesman.name,
      buyers.name, buyers.loadto,
      null, null, null
   from paidpt key join payspt join partners on partners.id=paidpt.partner
     key join buyers join palm_salesman on partners.parent=palm_salesman.srv_pgroup
 where (@salesman is null or palm_salesman.salesman_id=@salesman)
 union all
 select 3, 2,
      palm_salesman.name,
      buyers.name, buyers.loadto,
      payspt.info, date(payspt.ddate), sum(paidpt.csum)
   from paidpt key join payspt join partners on partners.id=paidpt.partner
     key join buyers join palm_salesman on partners.parent=palm_salesman.srv_pgroup
 where (@salesman is null or palm_salesman.salesman_id=@salesman)
group by palm_salesman.name,
      buyers.name, buyers.loadto,
      payspt.info, date(payspt.ddate)
order by 3,4,5,6
for xml explicit
end;
