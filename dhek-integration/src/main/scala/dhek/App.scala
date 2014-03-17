package dhek

import java.io.File
import javax.servlet.{
  Filter,
  FilterConfig,
  FilterChain,
  MultipartConfigElement,
  ServletRequest,
  ServletResponse
}
import javax.servlet.http.{ HttpServletRequest, HttpServletResponse }

import Extractor.{ &, Attributes, GET, POST, Path }

object App extends Filter with App {
  def destroy() {}
  def init(config: FilterConfig) {}

  def doFilter(req: ServletRequest, resp: ServletResponse, chain: FilterChain) {
    val hreq = req.asInstanceOf[HttpServletRequest]
    val hresp = resp.asInstanceOf[HttpServletResponse]

    hresp.setCharacterEncoding("UTF-8")

    hreq match {
      case GET(Path("/")) ⇒ home(hreq, hresp)
      case POST(Path("/upload")) & Attributes(Pdf(p) & Json(j)) ⇒
        modelFusion(p, j, hresp)
      case _ ⇒ chain.doFilter(req, resp)
    }
  }
}

trait App extends Html {
  import java.io.InputStreamReader

  import argonaut._, Argonaut._
  import com.itextpdf.text.{ Document, Image, BaseColor }
  import com.itextpdf.text.pdf.{ PdfReader, PdfWriter, PdfStamper }
  import resource.managed

  case class Rect(x: Int, y: Int, h: Int, w: Int, name: String, typ: String)
  case class Page(areas: Option[List[Rect]])
  case class Model(format: String, pages: List[Page])

  object Pdf {
    def unapply(attrs: Map[String, Any]) =
      attrs.get("pdf").map(_.asInstanceOf[File])
  }

  object Json {
    def unapply(attrs: Map[String, Any]) =
      attrs.get("json").map(_.asInstanceOf[File])
  }

  object Rect {
    implicit def rectCodecJson =
      casecodec6(Rect.apply, Rect.unapply)(
        "x", "y", "height", "width", "name", "type")
  }

  object Page {
    implicit def pageCodecJson =
      casecodec1(Page.apply, Page.unapply)("areas")
  }

  object Model {
    implicit def modelCodecJson =
      casecodec2(Model.apply, Model.unapply)("format", "pages")
  }

  val multipartConfigElement =
    new MultipartConfigElement("tmp", 1048576, 1048576, 262144)

  def home(req: HttpServletRequest, resp: HttpServletResponse) {
    resp.getWriter.print(index)
  }

  private def onError(resp: HttpServletResponse)(e: String) {
    resp.setStatus(400)
    resp.getWriter.print(e)
  }

  def modelFusion(pdf: File, json: File, resp: HttpServletResponse) {

    def onJsonSuccess(m: Model) {

      managed(new PdfReader(new java.io.FileInputStream(pdf))).acquireAndGet { reader ⇒
        managed(new PdfStamper(reader, resp.getOutputStream)).acquireAndGet { stamper ⇒

          resp.setContentType("application/pdf")

          m.pages.foldLeft(1) { (i, p) ⇒
            val page = stamper.getImportedPage(reader, i)
            val pageRect = reader.getPageSize(i)
            val over = stamper.getOverContent(i)

            for {
              rects ← p.areas.toList
              rect ← rects
            } yield {
              over.saveState()
              over.setLineWidth(2)
              over.setColorStroke(BaseColor.RED)
              over.rectangle(rect.x, pageRect.getHeight - rect.y - rect.h, rect.w, rect.h)
              over.stroke()
              over.restoreState()
            }

            i + 1
          }
        }
      }
    }

    lazy val jsonReader = new java.io.FileReader(json)

    Parse.decodeEither[Model](loadReader(jsonReader)).
      fold(onError(resp), onJsonSuccess)
  }
}
