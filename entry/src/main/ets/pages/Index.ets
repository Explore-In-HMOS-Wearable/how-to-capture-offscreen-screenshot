import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { ScreenshotDestination, ScreenshotParams } from './Screenshot';

@Entry
@Component
struct Index {
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();
  @State private previewPixelMap: image.PixelMap | undefined = undefined;
  @State private statusText: ResourceStr = $r('app.string.status_ready');
  @State private imageDetails: string = '';
  @State private savedPath: string = '';
  @State private isCapturing: boolean = false;
  @State private hasError: boolean = false;

  private readonly context: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;

  private getString(resource: Resource, ...args: Array<string | number>): string {
    try {
      return this.context.resourceManager.getStringSync(resource.id, ...args);
    } catch (error) {
      const businessError = error as BusinessError;
      console.error(businessError.message);
      return '';
    }
  }

  @Builder
  offscreenComponent() {
    Column({ space: 16 }) {
      Text($r('app.string.offscreen_badge'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Text($r('app.string.offscreen_component_title'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Divider()
        .color($r('app.color.offscreen_divider'))

      Text($r('app.string.offscreen_component_description'))
        .fontSize(15)
        .fontColor($r('app.color.offscreen_text'))
        .textAlign(TextAlign.Center)

      Column({ space: 6 }) {
        Text($r('app.string.offscreen_capture_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.offscreen_capture_description'))
          .fontSize(14)
          .fontColor($r('app.color.offscreen_text'))
      }
      .width('100%')
      .padding(14)
      .borderRadius(14)
      .backgroundColor($r('app.color.offscreen_panel'))

      Column({ space: 6 }) {
        Text($r('app.string.offscreen_process_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.offscreen_process_description'))
          .fontSize(14)
          .fontColor($r('app.color.offscreen_text'))
      }
      .width('100%')
      .padding(14)
      .borderRadius(14)
      .backgroundColor($r('app.color.offscreen_panel'))

      Column({ space: 6 }) {
        Text($r('app.string.offscreen_save_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.offscreen_save_description'))
          .fontSize(14)
          .fontColor($r('app.color.offscreen_text'))
      }
      .width('100%')
      .padding(14)
      .borderRadius(14)
      .backgroundColor($r('app.color.offscreen_panel'))

      Column({ space: 6 }) {
        Text($r('app.string.offscreen_display_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.offscreen_display_description'))
          .fontSize(14)
          .fontColor($r('app.color.offscreen_text'))
      }
      .width('100%')
      .padding(14)
      .borderRadius(14)
      .backgroundColor($r('app.color.offscreen_panel'))
    }
    .width(280)
    .height(720)
    .padding(24)
    .borderRadius(32)
    .linearGradient({
      angle: 135,
      colors: [
        [$r('app.color.offscreen_gradient_start'), 0.0],
        [$r('app.color.offscreen_gradient_end'), 1.0]
      ]
    })
  }

  private async savePixelMap(pixelMap: image.PixelMap): Promise<string> {
    const filePath = `${this.context.filesDir}/offscreen_component_${Date.now()}.jpg`;
    const imagePacker = image.createImagePacker();
    let outputFile: fileIo.File | undefined = undefined;

    try {
      outputFile = fileIo.openSync(
        filePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE
      );
      await imagePacker.packToFile(pixelMap, outputFile.fd, {
        format: 'image/jpeg',
        quality: 95
      });
      return filePath;
    } catch (error) {
      const businessError = error as BusinessError;
      throw new Error(this.getString(
        $r('app.string.save_failure'),
        businessError.code,
        businessError.message
      ));
    } finally {
      if (outputFile) {
        try {
          fileIo.closeSync(outputFile);
        } catch (error) {
          const businessError = error as BusinessError;
          console.error(this.getString($r('app.string.close_file_failure'), businessError.message));
        }
      }
      try {
        await imagePacker.release();
      } catch (error) {
        const businessError = error as BusinessError;
        console.error(this.getString($r('app.string.release_packer_failure'), businessError.message));
      }
    }
  }

  private async captureOffscreenComponent(): Promise<void> {
    if (this.isCapturing) {
      return;
    }

    this.isCapturing = true;
    this.hasError = false;
    this.statusText = $r('app.string.status_rendering');
    this.imageDetails = '';
    this.savedPath = '';
    let capturedPixelMap: image.PixelMap | undefined = undefined;

    try {
      capturedPixelMap = await this.getUIContext()
        .getComponentSnapshot()
        .createFromBuilder(() => {
          this.offscreenComponent();
        });

      const imageInfo = capturedPixelMap.getImageInfoSync();
      const filePath = await this.savePixelMap(capturedPixelMap);
      const previousPixelMap = this.previewPixelMap;

      this.previewPixelMap = capturedPixelMap;
      capturedPixelMap = undefined;
      this.imageDetails = this.getString(
        $r('app.string.image_details'),
        imageInfo.size.width,
        imageInfo.size.height
      );
      this.savedPath = filePath;
      this.statusText = $r('app.string.status_success');

      if (previousPixelMap) {
        await previousPixelMap.release();
      }
    } catch (error) {
      const captureError = error as Error;
      this.hasError = true;
      this.statusText = this.getString($r('app.string.status_failure'), captureError.message);
      if (capturedPixelMap) {
        await capturedPixelMap.release();
      }
    } finally {
      this.isCapturing = false;
    }
  }

  private showScreenshot(): void {
    if (this.savedPath.length === 0) {
      return;
    }

    try {
      const params: ScreenshotParams = { filePath: this.savedPath };
      this.pathStack.pushPathByName('Screenshot', params);
    } catch (error) {
      const businessError = error as BusinessError;
      this.hasError = true;
      this.statusText = this.getString($r('app.string.navigation_failure'), businessError.message);
    }
  }

  aboutToDisappear(): void {
    const pixelMap = this.previewPixelMap;
    this.previewPixelMap = undefined;
    if (pixelMap) {
      pixelMap.release().catch((error: BusinessError) => {
        console.error(this.getString($r('app.string.release_pixelmap_failure'), error.message));
      });
    }
  }

  @Builder
  homeContent() {
    Scroll() {
      Column({ space: 12 }) {
        Text($r('app.string.page_title'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text($r('app.string.page_description'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)

        Button(this.isCapturing ? $r('app.string.capturing_action') : $r('app.string.capture_action'))
          .enabled(!this.isCapturing)
          .width('90%')
          .onClick(() => {
            this.captureOffscreenComponent();
          })

        Text(this.statusText)
          .fontSize(13)
          .fontColor(this.hasError ? $r('app.color.status_error') : $r('app.color.status_success'))
          .textAlign(TextAlign.Center)

        if (this.previewPixelMap) {
          Text($r('app.string.preview_title'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))

          Image(this.previewPixelMap)
            .width(150)
            .height(150)
            .objectFit(ImageFit.Contain)
            .borderRadius(16)

          Text(this.imageDetails)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))

          Text(this.savedPath)
            .fontSize(11)
            .fontColor($r('app.color.text_muted'))
            .textAlign(TextAlign.Center)
            .maxLines(3)

          Button($r('app.string.show_screenshot_action'))
            .width('90%')
            .onClick(() => {
              this.showScreenshot();
            })
        }
      }
      .width('100%')
      .padding({ top: 24, right: 18, bottom: 24, left: 18 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    .scrollBar(BarState.Off)
  }

  @Builder
  destinationMap(name: string, param: Object) {
    if (name === 'Screenshot') {
      ScreenshotDestination({ params: param as ScreenshotParams });
    }
  }

  build() {
    Navigation(this.pathStack) {
      this.homeContent();
    }
    .navDestination(this.destinationMap)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .width('100%')
    .height('100%')
  }
}
