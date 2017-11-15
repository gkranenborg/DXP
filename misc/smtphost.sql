SET verify off;

BEGIN
update IBPMPROPERTIES set PROPERTYVALUE='interstagedemo' where PROPERTYKEY='SMTPServerHost';
update IBPMPROPERTIES set PROPERTYVALUE='2525' where PROPERTYKEY='SMTPServerPort';
END;
/

QUIT;
/
