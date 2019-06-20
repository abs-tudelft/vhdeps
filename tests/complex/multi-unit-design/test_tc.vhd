entity test_tc is
end test_tc;

architecture struct of test_tc is
begin
  a_inst: entity work.a;
  b_inst: entity work.b;
  d_inst: entity work.d;
end struct;
