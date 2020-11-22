function [] = phal_sendmail(subject, message, recipient)
% Sends an email to one recipient
%   Inputs:
%   - SUBJECT (string) is mandatory, no mail will be sent without  it
%   - MESSAGE (string) can be empty, is the message body
%   - RECIPIENT (string) has to be a valid e-mail address
%       if no recipient is given, the e-mail will be sent to the below
%       default address
defaultrecipient = 'someone@somewhere.com';
sendermail = 'sender@gmail.com'; 
senderpass = 'senderpassword';
emailserver = 'smtp.gmail.com';
port = '465';
% port = '587';


if ~exist('recipient', 'var')
    recipient = defaultrecipient;
else
    expression = '\w*\@\w*[.]\w*';
    match = regexp(recipient, expression);
    if ~match
        disp('not a valid recipient')
        disp('no message sent')
        return
    end
end
if ~exist('message', 'var')
    message = [datestr(now, 'HH:MM:SS  '), 'This message has been automatically sent from Matlab'];
else 
    message = ['This message has been automatically sent from Matlab', newline, datestr(now, 'HH:MM:SS  '), message];
end
if ~exist('subject', 'var')
    disp('please give a subject')
    disp('no message sent')
    return
elseif ~ischar(subject)
        disp('subject has to be a string')
        disp('no message sent')
        return
end

encoding = 'UTF-8';

props = java.lang.System.getProperties;

props.setProperty('mail.smtp.auth','true');
props.setProperty('mail.smtp.port',port);

% seems necessary
props.setProperty('mail.smtp.socketFactory.class', 'javax.net.ssl.SSLSocketFactory');
props.setProperty('mail.smtp.socketFactory.port','465');

% not necessary
% props.setProperty('mail.smtp.host', emailserver);  
% props.setProperty('mail.smtp.starttls.enable', 'true');
% props.setProperty('mail.smtp.ssl.enable', 'true');

setpref('Internet','SMTP_Server', emailserver);
setpref('Internet','E_mail',sendermail);
setpref('Internet','SMTP_Username',sendermail);
setpref('Internet','SMTP_Password',senderpass);
setpref('Internet','E_mail_Charset', encoding);

disp(['sending message to ', recipient])
sendmail(recipient, subject, message)
end