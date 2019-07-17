--pragma simulation timeout 1 ms

entity test_tc is
end test_tc;

architecture behav of test_tc is
  signal clk : boolean;
begin
  report_proc: process is
  begin
    wait for 5 ns;
    clk <= false;
    wait for 5 ns;
    clk <= true;
  end process;
end behav;
