entity c is
end c;

architecture struct of c is
begin
  b_inst: entity work.b;
end struct;

entity d is
end d;

architecture struct of d is
begin
  c_inst: entity work.c;
end struct;
