concept _xml;

method '_xml.NodeContent', public;
method '_xml.NodeExists', public;

alter function _xml.NodeExists (in @xml xml, in @path varchar(256))
returns integer
begin
 declare @result integer;
 select count(*) into @result from openxml(@xml,@path) with (data text '.');
 return @result
end;

alter function _xml.NodeContent (in @xml xml, in @path varchar(256))
returns xml
begin
 declare @result xml;
 select xmlagg(data) into @result from openxml(@xml,@path) with (data xml '@mp:xmltext');
 return @result
end;
