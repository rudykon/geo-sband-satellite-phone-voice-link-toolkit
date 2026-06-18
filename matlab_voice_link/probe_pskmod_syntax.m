disp('probe pskmod syntax');
b = [0;0;0;1;1;0;1;1];
y = pskmod(b, 4, pi/4, InputType='bit');
z = pskdemod(y, 4, pi/4, OutputType='bit');
disp([b z]);
disp('done');
