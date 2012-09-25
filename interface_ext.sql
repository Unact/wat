concept interface;

define 'function', 'interface.proce';
define 'function', 'interface.getdata';
define 'function', 'interface.putdata';
define 'function', 'interface.TransformXml';
define 'service' , 'xml';

define 'procedure', 'interface.return_as_xml';
define 'procedure', 'interface.return_as_text';
define 'function' , 'interface.ValidatePassword';
define 'function' , 'interface.ValidatePassword_soa';

/*
CREATE SERVER rc_unact
CLASS 'SAJDBC'
USING 'asa0.unact.ru:2638/rc_unact';

create externlogin dba to rc_unact remote login dba identified by 'sqlea';

CREATE SERVER rc_unact_old
CLASS 'SAJDBC'
USING 'hqsrv12.unact.ru:2639/rc_unact_old';

create externlogin dba to rc_unact_old remote login dba identified by 'sqlea';

*/


if not exists (select * from systable where table_name='remote_request_test' and creator=user_id('interface')) then


  create existing table interface.remote_request_test (
    id uniqueidentifier, type varchar(32), request long varchar, response long varchar
  ) at 'rc_unact_old..interface.request'


end if;


if not exists (select * from systable where table_name='remote_request_prod' and creator=user_id('interface')) then

  create existing table interface.remote_request_prod (
    id uniqueidentifier, type varchar(32), request long varchar, response long varchar
  ) at 'rc_unact..interface.request'
  

end if;

sa_make_object 'view', remote_request, interface;


alter view interface.remote_request as 
 select * from interface.remote_request_prod
;


alter procedure interface.return_as_text (in @text text)
begin

 call sa_set_http_header ( 'Content-Type', 'text/css' );
 call sa_set_http_option ( 'CharsetConversion', 'off');

 select @text;

end;

alter procedure interface.return_as_xml (in @xml xml)
begin
 declare @type varchar(10);

 set @type= 
   case left(@xml,5)
     when '<html' then 'html'
     when '<!DOC' then 'html'
     else if left(@xml,1)='<' then 'xml' else 'plain' endif
   end
 ;


 call sa_set_http_header ( 'Content-Type', 'text/'+@type );
 call sa_set_http_option ( 'CharsetConversion', 'off');

 select if @xml<>'' and left(@xml,5) <> '<?xml' and @type<>'plain' then
'<?xml version="1.0" encoding="windows-1251" ?>
'
 else '' endif +@xml
end;


alter function interface.TransformXml (xslurl varchar(256), xsltext xml, xmltext xml )
returns xml
url 'https://soa.unact.ru/xmlTransformator/Default.aspx'
type 'HTTP:POST'
certificate 'file=c:\work\wat\soa.unact.ru'
;


alter function interface.ValidatePassword_soa (username varchar(128), password varchar(128))
returns varchar(10)
url 'https://soa.unact.ru/AuthenticationService/Default.aspx'
type 'HTTP:POST'
certificate 'file=c:\work\wat\soa.unact.ru';

alter function interface.ValidatePassword (username varchar(128), password varchar(128))
returns varchar(10)
begin

 if username='11' and password='22' then
   return 'true'
 end if;

 return interface.ValidatePassword_soa (username, password)

end;



alter function interface.getdata ()
returns xml
begin
  declare @response long varchar;
  declare @id uniqueidentifier;
  declare @request long varchar;

  set @request=xmlelement('request',xmlattributes(_session_username as "username"));

  set @id=newid();
  
  insert into interface.remote_request (id, type, request) values (@id, 'get', @request);

  select response 
    into @response 
    from interface.remote_request 
   where id=@id
  ;

  return @response;
end;




alter function interface.putdata (data xml)
returns xml
begin
  declare @response long varchar;
  declare @id uniqueidentifier;

  set @id=newid();

  set @response=data;
  
  insert into interface.remote_request (id, type, request) values (@id, 'put', @response)
  ;
  select response 
    into @response 
    from interface.remote_request 
   where id=@id
  ;

  return @response;
end;



alter function interface.proce (in @command varchar(128) default null, in @request_id int default null)
returns xml
begin
 declare @response xml;
 declare @session_id uniqueidentifier;

 set @command=nullif(@command,'');
 set @request_id=nullif(@request_id,'');

 if @command='submit' then
   return resp(@request_id);
 end if;

 set @session_id = db.getvar('_session_id');

 if @command='logoff' or @session_id is null or not exists(select * from _session where id=@session_id) then
 auth: begin
   declare @uid varchar(128);
   declare @pwd varchar(128);
   
   call sa_set_http_option('SessionID', null );
   
   select nullif(http_variable('username'),''), http_variable('password')
     into @uid, @pwd;

   if @uid is not null then
     if interface.ValidatePassword (@uid,@pwd)='true' then
        set @session_id = _session.register();
        call request.setforward();
        return 'Authentication successful'
     end if
   end if;

   return interface.auth(@uid);

 end
 else 
   call _session.register(); -- Actually does session data refresh, not register
 end if;

 set @request_id=coalesce(@request_id,db.getvar('forward_request'), request.register (@command));

 set @response=coalesce(
      (select data from request where id=@request_id), db.getvar('forward_data'), getdata()
 );

 call db.setvar('forward_data',null);
 call db.setvar('forward_request',null);

 if not isnull(http_variable('url1'),'')='db'then
   set @response=TransformXml(null,xsl_makeid(@request_id),@response);
   update request set response=@response where id=@request_id;
 end if;
 
 if not isnull(http_variable('url1'),'') in ('db', 'nostyle') then
    set @response=TransformXml(null,xsl(_session_device),@response)
 else
    set @response=TransformXml(null,xsl_format(),@response);
 end if;

 return @response;

end;


alter service "xml"
type 'raw'
authorization off user dba
url elements
as call interface.return_as_xml (interface.proce(:command,:request_id))
;
