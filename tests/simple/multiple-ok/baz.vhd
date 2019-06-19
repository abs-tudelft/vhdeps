--pragma simulation timeout 1 ms

entity baz is
end baz;

architecture behav of baz is
begin
  report_proc: process is
  begin
    wait for 10 ns;
    report "working!" severity note;
    wait;
  end process;
end behav;
