import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

export interface ScreenshotParams {
  filePath: string;
}

@Component
export struct Screenshot {
  @Consume('pathStack') pathStack: NavPathStack;
  @Prop params: ScreenshotParams;
  @State private screenshot: image.PixelMap | undefined = undefined;
  @State private statusText: ResourceStr = $r('app.string.screenshot_loading');
  @State private displayHeight: number = 280;
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

  private async loadScreenshot(): Promise<void> {
    let inputFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;

    try {
      if (!this.params.filePath) {
        this.hasError = true;
        this.statusText = $r('app.string.screenshot_path_missing');
        return;
      }

      inputFile = fileIo.openSync(this.params.filePath, fileIo.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(inputFile.fd);
      const pixelMap = await imageSource.createPixelMap();
      const imageInfo = pixelMap.getImageInfoSync();

      this.displayHeight = 280 * imageInfo.size.height / imageInfo.size.width;
      this.screenshot = pixelMap;
      this.statusText = $r('app.string.screenshot_loaded');
    } catch (error) {
      const businessError = error as BusinessError;
      this.hasError = true;
      this.statusText = this.getString($r('app.string.screenshot_load_failure'), businessError.message);
    } finally {
      if (inputFile) {
        try {
          fileIo.closeSync(inputFile);
        } catch (error) {
          const businessError = error as BusinessError;
          console.error(this.getString($r('app.string.close_file_failure'), businessError.message));
        }
      }
      if (imageSource) {
        try {
          await imageSource.release();
        } catch (error) {
          const businessError = error as BusinessError;
          console.error(this.getString($r('app.string.release_image_source_failure'), businessError.message));
        }
      }
    }
  }

  aboutToAppear(): void {
    this.loadScreenshot();
  }

  aboutToDisappear(): void {
    const pixelMap = this.screenshot;
    this.screenshot = undefined;
    if (pixelMap) {
      pixelMap.release().catch((error: BusinessError) => {
        console.error(this.getString($r('app.string.release_pixelmap_failure'), error.message));
      });
    }
  }

  build() {
    Column({ space: 4 }) {
      Row({ space: 4 }) {
        Text($r('app.string.back_symbol'))
          .width(24)
          .height(24)
          .fontSize(18)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.offscreen_panel'))
          .borderRadius(12)
          .accessibilityText($r('app.string.back_action'))
          .onClick(() => {
            this.pathStack.pop();
          })

        Text($r('app.string.screenshot_page_title'))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('68%')

      Text(this.statusText)
        .fontSize(10)
        .fontColor(this.hasError ? $r('app.color.status_error') : $r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .width('70%')

      Scroll() {
        Column() {
          if (this.screenshot) {
            Image(this.screenshot)
              .width(280)
              .height(this.displayHeight)
              .objectFit(ImageFit.Fill)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 28, right: 6, bottom: 8, left: 6 })
    .backgroundColor($r('app.color.page_background'))
  }
}

@Component
export struct ScreenshotDestination {
  @Prop params: ScreenshotParams;

  build() {
    NavDestination() {
      Screenshot({ params: this.params })
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.page_background'))
  }
}
