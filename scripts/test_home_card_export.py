#!/usr/bin/env python3
"""Exercise the explicit crop contract using deterministic, text-free fixtures."""
import json, subprocess, tempfile, unittest, struct
from pathlib import Path
from home_card_manifest_io import swift_helper, atomic_json

class ExportContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.helper=swift_helper('export_home_card_reference')

    def source(self, folder, width, height):
        # System CoreGraphics fixture creation; this is exporter testing, not artwork.
        script=folder/'fixture.swift'
        script.write_text('''import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let c=CGContext(data:nil,width:WIDTH,height:HEIGHT,bitsPerComponent:8,bytesPerRow:WIDTH*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
c.setFillColor(CGColor(red:0,green:0,blue:1,alpha:1));c.fill(CGRect(x:0,y:0,width:WIDTH,height:HEIGHT))
let d=CGImageDestinationCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[1]) as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(d,c.makeImage()!,nil);CGImageDestinationFinalize(d)
'''.replace('WIDTH',str(width)).replace('HEIGHT',str(height)))
        path=folder/'source.png'
        subprocess.run(['xcrun','swift',str(script),str(path)],check=True,capture_output=True)
        return path

    def export(self, folder, source, spec):
        path=folder/'spec.json';atomic_json(path,spec)
        return subprocess.run([self.helper,str(source),str(folder/'export.png'),str(path),str(folder/'transform.json')],capture_output=True,text=True)

    def testIntentionalPaddingDoesNotConsumeAspectAllowance(self):
        with tempfile.TemporaryDirectory() as name:
            f=Path(name);source=self.source(f,1024,1024)
            result=self.export(f,source,dict(requested_canvas_pixels=[512,512],card_rect_pixels=[128,0,256,512],final_export_pixels=[256,512],appearance='light'))
            self.assertEqual(result.returncode,0,result.stderr)
            transform=json.loads((f/'transform.json').read_text())
            self.assertEqual(transform['intentional_padding_fraction'],0.5)
            self.assertEqual(transform['unintended_crop_fraction'],0)
            self.assertEqual(transform['actual_card_rect_pixels'],[256,0,512,1024])
            self.assertEqual(struct.unpack('>II',(f/'export.png').read_bytes()[16:24]),(256,512))

    def testUnintendedAspectChangeIsRejected(self):
        with tempfile.TemporaryDirectory() as name:
            f=Path(name);source=self.source(f,1024,1024)
            result=self.export(f,source,dict(requested_canvas_pixels=[512,1024],card_rect_pixels=[0,0,512,1024],final_export_pixels=[512,1024],appearance='dark'))
            self.assertEqual(result.returncode,2)
            self.assertFalse((f/'export.png').exists())

    def testOutOfBoundsCardIsRejected(self):
        with tempfile.TemporaryDirectory() as name:
            f=Path(name)
            result=self.export(f,f/'unused.png',dict(requested_canvas_pixels=[512,512],card_rect_pixels=[500,0,32,32],final_export_pixels=[32,32],appearance='light'))
            self.assertEqual(result.returncode,2)
            self.assertIn('outside',result.stderr)

if __name__=='__main__': unittest.main()
