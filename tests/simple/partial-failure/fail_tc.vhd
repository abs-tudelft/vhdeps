--pragma simulation timeout 1 ms

entity fail_tc is
end fail_tc;

architecture behav of fail_tc is
begin
  report_proc: process is
  begin
    wait for 10 ns;
    report "uh oh!" severity failure;
    wait;
  end process;
end behav;
