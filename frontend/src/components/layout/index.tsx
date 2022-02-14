
import Head from 'next/head';
import Footer from './footer';
import Header from './header';
import css from './layout.module.css';

export interface LayoutProps {
    children: JSX.Element;
}

const Layout = ({children}: LayoutProps): JSX.Element => {
    return(
        <>
            <Head>
                <title>Defi Syndicate</title>
                <meta name="viewport" content="initial-scale=1, width=device-width" />
            </Head>
            <div className={css.layoutContainer}>
                <Header></Header>
                    {children}
                <Footer></Footer>
            </div>
        </>
    );
}

export default Layout;