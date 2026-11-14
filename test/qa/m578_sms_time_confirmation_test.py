"""M578: edited bank SMS requires exact date AND hour/minute confirmation."""
from pathlib import Path
from waffra_home_source import read_waffra_home_source
import unittest
SRC=read_waffra_home_source()

class BankSmsTimeConfirmation(unittest.TestCase):
 def test_calendar_then_clock_are_mandatory(self):
  editor=SRC.split('Future<void> entrySheet(',1)[1].split('Future<void> showReceipt(',1)[0]
  for marker in ('if(sms){','final time=await showTimePicker(',
   'TimeOfDay.fromDateTime(date)',
   'DateTime(d.year,d.month,d.day,time.hour,time.minute)',
   'if(time==null||!sheetContext.mounted)return;',
   'confirmed.isAfter(DateTime.now())',
   'smsDateConfirmed=true;', 'sms&&!smsDateConfirmed?',
   'اختر التاريخ والوقت',
   "date.hour.toString().padLeft(2,'0')", 
   "date.minute.toString().padLeft(2,'0')"):
   self.assertIn(marker,editor)
  self.assertIn('var smsDateConfirmed=initial!=null||',editor)
  self.assertIn('if(!smsDateConfirmed){',editor)
  self.assertIn("'dateConfirmed':smsDateConfirmed,",editor)

if __name__=='__main__':unittest.main()
