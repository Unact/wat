concept request;

method 'request.register', interface;
method 'request.setforward', interface;

method 'db.setvar', public;
method 'db.getvar', public;

alter procedure db.setvar (
 in @name varchar(128), in @value long varchar, in @type varchar(128) default 'long varchar')
begin
 if varexists ( @name ) <> 1 then
    execute immediate 'create variable '+@name+' '+@type;
 end if;

 execute immediate 'set '+@name+'='+if @value is null then 'null' else ''''+@value+'''' endif;

end;


alter function db.getvar (in @name varchar(128))
returns long varchar
begin
 declare @result long varchar;

 if varexists ( @name ) =1 then
   execute immediate 'set @result='+@name;
 end if;

 return @result;
end;
 


if not exists (select * from systable where table_name='request' and creator=user_id('request')) then

  create table request.request (
    id int default autoincrement,
    ts datetime default current timestamp,
    command varchar(256), data xml, response xml, submit xml, data_put xml,
    foreign key ( forward_request ) references request.request,
    foreign key ( session_id ) references _session._session,
    primary key (id)
  );

  create view interface.request
  as
  select * from request.request
  ;

  grant select, update on interface.request to interface;

end if;


alter function request.register (in @command varchar(256), in @data xml default null)
returns int
begin
 declare @result int;

 insert into request (session_id, data, command)
   values (_session_id, @data, @command)
 ;

 set @result=@@identity;
 
 return @result;

end;


alter function request.setforward (in @command varchar(256) default null, in @data xml default null)
returns int
begin
  declare @result int;

  call sa_set_http_header ('@HTTPSTATUS', '302');
  call sa_set_http_header ('Location', if @command is null then '/xml' else '?command='+@command endif);

  call db.setvar ('forward_data',@data);
  set @result=request.register (@command,@data);
  call db.setvar ('forward_request', @result);

  return @result;

end;


