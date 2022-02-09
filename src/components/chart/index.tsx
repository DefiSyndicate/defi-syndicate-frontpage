import { Row, Col, Container } from "react-bootstrap";
import css from './chart.module.css';

const Chart = (): JSX.Element => {

    return(
        <Container id="chart" className={css.anchorTag}>
            <Row>
                <Col>
                    <div className={css.dexScreenerEmbed} id="dexscreener-embed">
                        <iframe className={css.dexScreenerEmbedIframe} src="https://dexscreener.com/avalanche/0x938e8B130E87D92d873FccA26bA144A32Ba12b93?embed=1"></iframe>
                    </div>
                </Col>
            </Row>
        </Container>
    );
}

export default Chart