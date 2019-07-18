--pragma simulation timeout 1 ms
--pragma vhdeps vsim flags -a
--pragma vhdeps vsim flags -b -c
--pragma vhdeps vcom flags -d -e

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
