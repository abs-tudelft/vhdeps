--pragma simulation timeout 1 ms

use std.textio.all;

entity test_tc is
end test_tc;

architecture behav of test_tc is
begin
  report_proc: process is
    file fil : text;
  begin
    wait for 10 ns;
    file_open(fil, "output_file.txt", write_mode);
    file_close(fil);
    report "working!" severity note;
    wait;
  end process;
end behav;
