entity a is
end a;

architecture struct of a is
begin
end struct;

entity c is
end c;

architecture struct of c is
begin
  b_inst: entity work.b;
end struct;
