--pragma simulation timeout 1 ms

entity test_tc is
end test_tc;

architecture behav of test_tc is
begin
  report_proc: process is
  begin
    invalid syntax;
  end process;
end behav;
