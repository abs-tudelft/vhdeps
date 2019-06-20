-- pragma simulation timeout 3 ms

entity test_tc is
end test_tc;
architecture behav of test_tc is
begin
  a_inst: entity work.a;
  b_inst: entity work.b;
  c_inst: entity work.c;
end behav;
