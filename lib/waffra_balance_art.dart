import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Vector illustration matching the approved emerald balance card.
///
/// All paths are embedded, so no network, remote image or storage access is
/// needed. Leaves and stacks remain crisp at every phone density.
class WaffraBalanceIllustration extends StatelessWidget {
 const WaffraBalanceIllustration({super.key});
 static const String _drawing = r'''
<svg xmlns="http://www.w3.org/2000/svg" width="202" height="162" viewBox="0 0 202 162">
 <defs>
  <linearGradient id="leaf" x1="0" x2="1" y1="0" y2="1">
   <stop stop-color="#88E7A0"/><stop offset=".44" stop-color="#16A66A"/>
   <stop offset="1" stop-color="#036647"/>
  </linearGradient>
  <linearGradient id="leaf2" x1="0" x2="1" y1="0" y2="1">
   <stop stop-color="#D7FFD3"/><stop offset=".4" stop-color="#4AC884"/>
   <stop offset="1" stop-color="#066544"/>
  </linearGradient>
  <linearGradient id="mint" x1="0" x2="1" y1="0" y2="0">
   <stop stop-color="#034D40"/><stop offset=".18" stop-color="#26B883"/>
   <stop offset=".48" stop-color="#057A5D"/><stop offset=".73" stop-color="#3CE59C"/>
   <stop offset="1" stop-color="#07563F"/>
  </linearGradient>
  <linearGradient id="gold" x1="0" x2="1" y1="0" y2="0">
   <stop stop-color="#A66716"/><stop offset=".19" stop-color="#EFB746"/>
   <stop offset=".45" stop-color="#FFF1B6"/><stop offset=".72" stop-color="#DCA237"/>
   <stop offset="1" stop-color="#8E5C20"/>
  </linearGradient>
  <linearGradient id="gold2" x1="0" x2="1" y1="0" y2="1">
   <stop stop-color="#FFF8BF"/><stop offset=".58" stop-color="#FFC75A"/>
   <stop offset="1" stop-color="#B87820"/>
  </linearGradient>
 </defs>
 <!-- Deep glow behind the living savings leaves -->
 <ellipse cx="121" cy="153" rx="81" ry="12" fill="#06482D" opacity=".45"/>
 <path d="M130 145 C122 98 125 61 138 21" stroke="#91E69C" stroke-width="2.5" fill="none"/>
 <path d="M135 92 C126 75 101 49 79 45 C84 68 103 95 135 92Z" fill="url(#leaf)"/>
 <path d="M132 81 C142 62 165 42 174 26 C159 30 131 48 132 81Z" fill="url(#leaf2)"/>
 <path d="M133 115 C146 95 171 83 191 73 C188 97 164 119 133 115Z" fill="url(#leaf)"/>
 <path d="M128 119 C108 99 87 91 63 92 C76 114 99 128 128 119Z" fill="url(#leaf2)"/>
 <path d="M127 130 C132 98 131 64 128 18 C109 36 103 88 127 130Z" fill="url(#leaf)"/>
 <path d="M131 128 C152 114 169 108 184 108 C172 131 152 140 131 128Z" fill="url(#leaf2)"/>
 <path d="M128 114 C107 92 97 64 97 40" stroke="#B7F2C4" opacity=".5" stroke-width="1.6" fill="none"/>
 <path d="M135 110 C155 97 171 91 189 74" stroke="#C4F8C6" opacity=".55" stroke-width="1.4" fill="none"/>
 <path d="M127 105 C127 77 125 51 126 21" stroke="#D5F6B6" opacity=".50" stroke-width="1.5" fill="none"/>
 <!-- leaf highlights and rolled green banknotes -->
 <path d="M52 140 C60 122 77 120 94 133 L105 148 L44 150Z" fill="#0B6749"/>
 <path d="M59 139 C73 129 82 132 93 141" stroke="#43CB7D" stroke-width="4" fill="none"/>
 <!-- short emerald stack -->
 <rect x="114" y="113" width="37" height="29" rx="4" fill="url(#mint)" stroke="#1AC787" stroke-width="1.6"/>
 <ellipse cx="132.5" cy="113" rx="18.5" ry="5" fill="#4BEAA1" stroke="#0B6E51"/>
 <path d="M114 123 Q132 130 151 123 M114 133 Q132 140 151 133" stroke="#68E8A6" stroke-width="1.5" fill="none" opacity=".9"/>
 <!-- high emerald stack -->
 <rect x="154" y="84" width="30" height="57" rx="5" fill="url(#mint)" stroke="#2FC98B" stroke-width="1.4"/>
 <ellipse cx="169" cy="84" rx="15" ry="5.5" fill="#62ECA8" stroke="#0C684C"/>
 <path d="M154 94 Q169 100 184 94 M154 105 Q169 111 184 105 M154 116 Q169 122 184 116 M154 127 Q169 133 184 127" stroke="#7DF5B2" stroke-width="1.6" fill="none" opacity=".8"/>
 <path d="M158 88 L161 134" stroke="#B6FFD0" opacity=".3" stroke-width="2.5"/>
 <!-- central golden stack, individual bright coin rims -->
 <rect x="87" y="102" width="33" height="42" rx="4" fill="url(#gold)" stroke="#FFE29B" stroke-width="1.1"/>
 <ellipse cx="103.5" cy="102" rx="16.5" ry="5.5" fill="url(#gold2)" stroke="#D99B36"/>
 <path d="M87 110 Q104 116 120 110 M87 119 Q104 125 120 119 M87 128 Q104 134 120 128 M87 137 Q104 143 120 137" fill="none" stroke="#FFF3B5" stroke-width="1.5"/>
 <path d="M91 105 V141" stroke="#FFF6BE" opacity=".48" stroke-width="3"/>
 <!-- foreground small coins -->
 <path d="M44 150 C45 134 49 127 64 127 C77 127 82 141 81 150Z" fill="#0E6345"/>
 <ellipse cx="66" cy="141" rx="21" ry="8" fill="#37B970" stroke="#A0F3AD" stroke-width="1.5"/>
 <path d="M48 142 C59 148 72 148 83 142" stroke="#036043" fill="none" stroke-width="2"/>
 <ellipse cx="105" cy="147" rx="31" ry="7" fill="#F4C96B" opacity=".35"/>
 <ellipse cx="161" cy="148" rx="27" ry="8" fill="#45E69F" opacity=".20"/>
</svg>
''';
 @override
 Widget build(BuildContext context) => SvgPicture.string(
  _drawing, fit:BoxFit.contain, allowDrawingOutsideViewBox:false,
  semanticsLabel:'Decorative savings plant with gold and emerald coins',
 );
}

/// Organic pale wave cutting into the bottom of the balance illustration.
class WaffraBalanceWavePainter extends CustomPainter {
 final Color color;
 const WaffraBalanceWavePainter(this.color);
 @override
 void paint(Canvas canvas,Size size) {
  final p=Paint()..color=color;
  final w=size.width,h=size.height;
  final wave=Path()..moveTo(0,h-6)
   ..cubicTo(w*.17,h-22,w*.28,h-15,w*.43,h-7)
   ..cubicTo(w*.63,h+5,w*.75,h-4,w,h-30)
   ..lineTo(w,h)..lineTo(0,h)..close();
  canvas.drawPath(wave,p);
 }
 @override
 bool shouldRepaint(covariant WaffraBalanceWavePainter old)=>old.color!=color;
}
