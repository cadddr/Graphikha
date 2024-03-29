import haxe.macro.Expr.Function;
import kha.Framebuffer;
import Render;
import kha.Color;
import kha.Scheduler;
import pgr.dconsole.DC;
import kha.Blob;
import kha.Image;
import haxe.io.Bytes;

import Utils.pixelsToBytes;
/*
Manages the workload of rendering pixels.
*/

interface IRenderSampler {
	public var backbuffer: Array<Color>;
    public function render(fb: Framebuffer): Void;
}

class SimpleRender implements IRenderSampler {
	public var backbuffer: Array<Color> = null;
    private var renderer: Render;
    public function new(renderer: Render) {
        this.renderer = renderer;
    }

    public function render(fb: Framebuffer): Void {
        fb.g1.begin();
		for (y in 0...fb.height) {
			for (x in 0...fb.width) {
                var pixelColor: Color = renderer.getPixelColor(x, y, fb.width, fb.height);
                fb.g1.setPixel(x, y, pixelColor);
			}
		}
		fb.g1.end();
    }
}

class BufferedRenderer implements IRenderSampler {
	// Caches pixel values before displaying
	private var renderer: Render;
	public var backbuffer: Array<Color>;

	public function new(renderer: Render) {
        this.renderer = renderer;
	}

	public function render(fb: Framebuffer): Void {
	   if (renderer.scene.SCENE_CHANGED) {
    		backbuffer = [for (xy in 0...fb.width * fb.height) 0xffffffff];
    
    		for (y in 0...fb.height) {
    			for (x in 0...fb.width) {
    				var pixelColor: Color = renderer.getPixelColor(x, y, fb.width, fb.height);
    				backbuffer[y * fb.width + x] = pixelColor;
    			}
    		}
            renderer.scene.SCENE_CHANGED = false;
		}
		draw(fb);	
	}	

	public function draw(fb: Framebuffer): Void {
		fb.g2.begin();
		var bytes: Bytes = pixelsToBytes(backbuffer, fb.width, fb.height);
		var image: Image = Image.fromBytes(bytes, fb.width, fb.height);
		fb.g2.drawImage(image, 0, 0);
		fb.g2.end();
	}
}

class NewAdaptiveRender extends BufferedRenderer {
	var callCount: Int = 0;
	var resolutionScale: Int = 256;
	var onRenderComplete = null;

	public function new(renderer: Render, onRenderComplete) {
		super(renderer);
		this.onRenderComplete = onRenderComplete;
	}

	override public function render(fb: Framebuffer): Void {
		if (resolutionScale == 1) {
			draw(fb);
			return;
		}

		if (callCount == 0) {
			backbuffer = [for (xy in 0...fb.width * fb.height) 0xff000000];
		}



		for (y in 0...fb.height) {
			for (x in 0...fb.width) {

				if (y % resolutionScale == 0) {
					if (x % resolutionScale == 0) {
						
						var pixelColor: Color = renderer.getPixelColor(x, y, fb.width, fb.height);
						backbuffer[y * fb.width + x] = pixelColor;
					}
				}
			}
		}
		resolutionScale = Std.int(Math.max(1, resolutionScale / 2));

		callCount = (callCount + 1) % (resolutionScale * resolutionScale);

		draw(fb);
	}
}

class AdaptiveRender implements IRenderSampler {
    /*
currently: re-render everything on each frame (blocking)

goal: render must take a fixed amount of time (given by framerate target)
* vary resolution scale (reuse previously rendered pixels at lower resolution)
* vary number of AA samples (reuse previous samples)
* once rendered suspend rendering until render parameters change (e.g. camera move)
* or start over when done
*/

    private var renderer: Render;

    static var frameTime: Float;
    static var resolutionScale: Int = 1;

    static var callCount: Int = 0;
    
	public var backbuffer: Array<Color>;

    public function new(renderer: Render) {
        this.renderer = renderer;
        DC.monitorField(Main, "frameTime", "frameTime");
        DC.monitorField(Main, "resolutionScale", "resolutionScale");
        DC.monitorField(Main, "callCount", "callCount");
        DC.registerClass(Main, "AdaptiveRender");
    }

    public function render(fb: Framebuffer): Void {
		if (callCount == 0) {
			backbuffer = [for (xy in 0...fb.width * fb.height) 0xffffffff];
		}
		var renderBeginTime = Scheduler.realTime();
		fb.g1.begin();
		for (y in 0...fb.height) {
			for (x in 0...fb.width) {

				if (y % resolutionScale == 0) {
					if (x % resolutionScale == 0) {
						var x_ = x + callCount % resolutionScale;
						var y_ = y + Std.int(callCount / resolutionScale);
						DC.beginProfile("PixelTime");
						var pixelColor: Color = renderer.getPixelColor(x_, y_, fb.width, fb.height);
						backbuffer[y_ * fb.width + x_] = pixelColor;
						DC.endProfile("PixelTime");
					}
				}
				fb.g1.setPixel(x, y, backbuffer[y * fb.width + x]);
			}
		}
		fb.g1.end();
		var renderEndTime = Scheduler.realTime();
		frameTime = renderEndTime - renderBeginTime;

		callCount = (callCount + 1) % (resolutionScale * resolutionScale);

		// if (frameTime < REFRESH_RATE) {
		// 	resolutionScale = Std.int(Math.max(Std.int(resolutionScale / 2), 1));
		// }
		// else {
		// 	resolutionScale = Std.int(Math.min(Std.int(resolutionScale * 2), 600));
		// }
	}
}