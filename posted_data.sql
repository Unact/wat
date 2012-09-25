define 'procedure', 'interface.posted_data';

alter function interface.posted_data ()
returns xml
begin

 declare @var varchar(256);
 declare @xml xml;

 declare local temporary table vardata
    ( var varchar(256), value long varchar null, primary key (var));

lp:
 loop

   set @var=next_http_variable(@var);
   
   if @var is null then 
      leave lp;
   end if;

   insert into vardata values (@var, http_variable (@var));
   
 end loop lp;

 set @xml = (select * from vardata for xml auto);
 
 return xmlelement (name formdata, @xml);

end