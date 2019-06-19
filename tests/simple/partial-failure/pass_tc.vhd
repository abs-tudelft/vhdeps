--pragma simulation timeout 1 ms

entity pass_tc is
end pass_tc;

architecture behav of pass_tc is
begin
  report_proc: process is
  begin
    wait for 10 ns;
    report "working!" severity note;
    wait;
  end process;
end behav;
