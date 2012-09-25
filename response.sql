define 'procedure', 'interface.resp'
;
define 'service', 'response';

alter  service response type 'raw' authorization off user dba as
 call interface.return_as_xml(interface.resp (:request_id));


alter function interface.resp (@request_id int)
returns xml
begin
 declare @result xml;

 body: begin
   declare @submit xml;
   declare @response xml;

-- Todo: проверить что сессия запроса и сабмита совпадает

   if isnull(@request_id,0)=0 then
     set @result=
          xmlelement('exception',xmlconcat(
               xmlelement('ErrorText','Request id not submitted')
          ))
   elseif not exists (select * from request where id=@request_id) then
     set @result=
          xmlelement('exception',xmlconcat(
               xmlelement('ErrorText','No request with submitted id'),
               xmlelement('request_id',@request_id)
          ))
   elseif (select forward_request from request where id=@request_id) is not null then
     set @result=
          xmlelement('exception',xmlconcat(
               xmlelement('ErrorText','Submitted request is already served'),
               xmlelement('request_id',@request_id)
          ))
   end if;

   if @result is not null then
     leave body
   end if;

   select response into @response from request where id=@request_id;

     set @submit=posted_data();

     update request
        set submit=@submit
      where id=@request_id
     ;

     set @submit=
         TransformXml(null,xsl_post(),
           xmlelement('submit',
                    xmlattributes ('http://unact.ru/interface' as "xmlns",
                                   'http://unact.ru/interface' as "xmlns:ifc"
                    ),
                    xmlconcat(@submit,@response))
         )
     ;

     set @result=putdata(@submit);

 
     set @result=xmlelement('response',
                    xmlattributes ('http://unact.ru/database' as "xmlns",
                                   'http://www.w3.org/2001/XMLSchema' as "xmlns:xs",
                                   'http://unact.ru/database' as "xmlns:db"
                    ),
                    xmlconcat(_xml.PathContent(@result,'/*:response/*'),
                              _xml.PathContent(@submit,'//*:data'),
                              _xml.PathContent(@submit,'//*:metadata')
                    )
     );
     

     update request
        set forward_request=request.setforward (command,@result)
      where id=@request_id
     ;

     set @result='';


 exception
   when others then
     set @result=
          xmlelement('exception',
                     xmlconcat(xmlelement('ErrorText',errormsg())
                              ,xmlelement('SQLSTATE',SQLSTATE)
                     )
          )
 end;

 return @result

end;