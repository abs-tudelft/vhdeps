entity test_tc is
end test_tc;

architecture behav of test_tc is
begin
  report_proc: process is
  begin
    wait for 10 ns;
    report "working!" severity note;
    wait;
  end process;
end behav;
