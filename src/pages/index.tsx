import { Col, Container, Row } from 'react-bootstrap';
import Image from 'next/image';
import css from '../styles/Home.module.css';
import { Button } from 'react-bootstrap';
import Chart from '../components/chart';

export default function Home() {
  return (
      <Container>
        <Row id="hero" className={css.anchorTag}>
          <Col className={`d-flex flex-column justify-content-center ${css.center}`}>
              <h1 className={css.heroMain}>Defi Syndicate</h1>
              <div className={css.heroTitle}>Welcome to the Syndicate</div>
          </Col>
        </Row>
        <Row id="about" className={css.anchorTag}>
          <Col className={`d-flex flex-column justify-content-center ${css.center}`}>
              <div className={`${css.heroSubtitle} ${css.darkFrame}`}>The DefiSyndicate is a multi-phased project that aims to iterate on the current defi landscape and introduce new innovations. We are focused on sustainability, gamification, tradeable utility, and flexibility. </div>
          </Col>
        </Row>
        <Row>
          <Col className={`d-flex flex-column justify-content-center ${css.center}`}>
            <div className={`${css.about2}`}>In order to innovate in this space you have to experiment and continuously adapt to the changing environment.</div>
          </Col>
        </Row>
        <Row>
          <Col className={`d-flex flex-column justify-content-center ${css.center}`}>
            <div>
              <Button>Join us for the journey!</Button>
            </div>
          </Col>
        </Row>
        <Row>
          <Col className={`d-flex flex-column justify-content-center ${css.center}`}>
            <Chart></Chart>
          </Col>
        </Row>
      </Container>
  );
}
